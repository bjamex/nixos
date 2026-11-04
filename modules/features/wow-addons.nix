# WoW Forever addon auto-updater: a daily user timer that checks each addon
# suite's GitHub releases and swaps in anything newer. The Battle.net install
# lives in Steam's Proton prefix for the non-Steam "Battle.net" shortcut, so
# the AddOns path below is tied to that compatdata id — if the shortcut is
# ever re-added, update `addonsDir`.
#
# Per suite it remembers the installed release tag and the exact folders that
# release unpacked (~/.local/state/wow-addon-update/<suite>.{tag,folders}).
# An update removes those folders, then moves the new ones in, so a release
# that renames or drops folders (Polestar 0.3.0 did) leaves nothing stale and
# no other addon is touched. Delete a suite's .tag file to force a reinstall.
#
# If WoW is running it exits 75 and Restart= retries every 30 min until the
# game is closed, so files never change under a live client. Logs:
# `journalctl --user -u wow-addon-update`; run now with
# `systemctl --user start wow-addon-update`.
{ ... }:
{
  flake.nixosModules.wowAddons =
    { pkgs, lib, ... }:
    let
      addonsDir = "$HOME/.local/share/Steam/steamapps/compatdata/3506403809/pfx/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns";

      # suite | GitHub repo | release tag prefix | asset name regex [| pre].
      # spoken-wow publishes several products from one repo, hence the tag
      # prefixes. A trailing "pre" lets that suite take GitHub pre-releases,
      # for addons that only ever publish those (WhatsTraining).
      suites = [
        "ellesmereui|EllesmereGaming/EllesmereUI|v|^EllesmereUI-v[0-9.]+\\.zip$"
        "polestar|fitzforge/polestar|v|^Polestar-[0-9.]+\\.zip$"
        "spoken|rusty-key/spoken-wow|spoken/v|^Spoken-[0-9.]+\\.zip$"
        "spoken-quests-audio|rusty-key/spoken-wow|quests-audio/v|^SpokenQuestsAudioAll-[0-9.]+\\.zip$"
        # OpenMap tags Forever and retail builds side by side (v0.7.5-beta vs
        # v0.7.1-beta-retail); the asset regex keeps it on the Forever ones.
        "openmap|openmap-world/openmap|v|^OpenMap-v[0-9.]+(-beta)?\\.zip$"
        "foreverlootsparkles|svengabr/ForeverLootSparkles|v|^ForeverLootSparkles-v[0-9.]+-forever\\.zip$"
        "skillup-forever|cjber/skillup-forever|v|^SkillUpForever-v[0-9.]+-forever\\.zip$"
        "handynotes|Nevcairiel/HandyNotes|v|^HandyNotes-v[0-9.]+\\.zip$"
        # Kemayo's Forever treasure/rare pins; needs the HandyNotes core above.
        "handynotes-forever|kemayo/wow-handynotes-forever|v|^HandyNotes_WoWForever-v[0-9]+-forever\\.zip$"
        "whatstraining|fusionpit/WhatsTraining||^WhatsTraining-[0-9.]+(-beta[0-9]+)?\\.zip$|pre"
        # Its Forever support lives in the _Mainline TOCs (Interface 16001).
        "shamanpower|taubut/ShamanPower|v|^ShamanPower-[0-9.]+\\.zip$"
        # DBM rather than BigWigs: BigWigs core loads on Forever but none of
        # its module packs (Classic, LittleWigs) ship Forever encounters yet.
        "dbm-core|DeadlyBossMods/DeadlyBossMods||^DBM-Core-[0-9.]+\\.zip$"
        "dbm-vanilla|DeadlyBossMods/DBM-Vanilla|r|^DBM-Vanilla[A-Za-z_]*-r[0-9]+\\.zip$"
        "dbm-dungeons|DeadlyBossMods/DBM-Dungeons||^DBM-Dungeons-[0-9]+\\.zip$"
      ];

      updater = pkgs.writeShellApplication {
        name = "wow-addon-update";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          gnugrep
          jq
          unzip
          procps
          libnotify
        ];
        text = ''
          addons="${addonsDir}"
          state="''${XDG_STATE_HOME:-$HOME/.local/state}/wow-addon-update"

          if [ ! -d "$addons" ]; then
            echo "No Forever AddOns folder at $addons, nothing to do"
            exit 0
          fi
          if pgrep -fi 'Wow\.exe' >/dev/null; then
            echo "WoW is running; retrying later"
            exit 75
          fi

          # (No compgen: writeShellApplication's non-interactive bash lacks it.)
          has_toc() {
            local f
            for f in "$1"/*.toc; do
              [ -e "$f" ] && return 0
            done
            return 1
          }

          mkdir -p "$state"
          tmp=$(mktemp -d "$state/tmp.XXXXXX")
          trap 'rm -rf "$tmp"' EXIT
          updated=()

          for entry in ${lib.escapeShellArgs suites}; do
            IFS='|' read -r suite repo prefix assetRe allowPre <<<"$entry"

            release=$(curl -fsSL --retry 3 "https://api.github.com/repos/$repo/releases?per_page=100" |
              jq -c --arg p "$prefix" --arg re "$assetRe" --arg pre "$allowPre" \
                '[.[] | select(.draft | not) | select($pre == "pre" or (.prerelease | not))
                      | select(.tag_name | startswith($p))
                      | select(any(.assets[]; .name | test($re)))][0]')
            tag=$(jq -r '.tag_name' <<<"$release")
            if [ "$tag" = "null" ] || [ -z "$tag" ]; then
              echo "$suite: no release found, skipping"
              continue
            fi
            if [ "$(cat "$state/$suite.tag" 2>/dev/null)" = "$tag" ]; then
              echo "$suite: $tag is current"
              continue
            fi

            url=$(jq -r --arg re "$assetRe" \
              '[.assets[] | select(.name | test($re))][0].browser_download_url' <<<"$release")
            if [ "$url" = "null" ]; then
              echo "$suite: $tag has no asset matching $assetRe, skipping"
              continue
            fi
            asset=$(basename "$url")
            echo "$suite: updating to $tag ($asset)"

            work="$tmp/$suite"
            mkdir -p "$work/x"
            curl -fsSL --retry 3 -o "$work/$asset" "$url"

            sums=$(jq -r '[.assets[] | select(.name == "SHA256SUMS")][0].browser_download_url' <<<"$release")
            if [ "$sums" != "null" ]; then
              curl -fsSL --retry 3 -o "$work/SHA256SUMS" "$sums"
              (cd "$work" && sha256sum -c --ignore-missing SHA256SUMS)
            fi

            unzip -q "$work/$asset" -d "$work/x"
            # Every top-level entry must be a real addon folder; refuse
            # anything else rather than spraying files into AddOns.
            for d in "$work/x"/*; do
              if [ ! -d "$d" ] || ! has_toc "$d"; then
                echo "$suite: unexpected '$(basename "$d")' in $asset, skipping suite"
                continue 2
              fi
            done

            # Multi-flavour zips (DBM ships every expansion's modules) carry
            # folders the Forever client never loads; leave those out.
            for d in "$work/x"/*; do
              if ! grep -qsE '^## Interface:.*16001' "$d"/*.toc; then
                echo "$suite: leaving out $(basename "$d") (no Forever TOC)"
                rm -rf "$d"
              fi
            done

            if [ -f "$state/$suite.folders" ]; then
              while IFS= read -r old; do
                [ -n "$old" ] && rm -rf "''${addons:?}/$old"
              done <"$state/$suite.folders"
            fi
            : >"$work/folders"
            for d in "$work/x"/*; do
              name=$(basename "$d")
              rm -rf "''${addons:?}/$name"
              mv "$d" "$addons/$name"
              echo "$name" >>"$work/folders"
            done
            mv "$work/folders" "$state/$suite.folders"
            echo "$tag" >"$state/$suite.tag"
            rm -rf "$work"
            updated+=("$suite ''${tag##*/}")
          done

          if [ ''${#updated[@]} -gt 0 ]; then
            printf -v body '%s\n' "''${updated[@]}"
            notify-send -a "WoW addons" "WoW addons updated" "$body" || true
          fi
        '';
      };
    in
    {
      environment.systemPackages = [ updater ];

      systemd.user.services.wow-addon-update = {
        description = "Update WoW Forever addons from GitHub releases";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe updater;
          # 75 = WoW running (or a network hiccup): try again in 30 min.
          Restart = "on-failure";
          RestartSec = "30min";
        };
      };

      systemd.user.timers.wow-addon-update = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          # Catch up at login if the PC was off at midnight.
          Persistent = true;
          RandomizedDelaySec = "15min";
        };
      };
    };
}

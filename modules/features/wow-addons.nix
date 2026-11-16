# WoW Forever addon auto-updater: a daily user timer that checks each addon
# suite's GitHub releases (or CurseForge files, for addons only published
# there) and swaps in anything newer. The Battle.net install
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
# `systemctl --user start wow-addon-update`, or `wow-addon-update --force`
# to install while playing and /reload after.
{ ... }:
{
  flake.nixosModules.wowAddons =
    { pkgs, lib, ... }:
    let
      addonsDir = "$HOME/.local/share/Steam/steamapps/compatdata/3506403809/pfx/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns";

      # suite | GitHub repo | release tag prefix | asset name regex [| pre].
      # spoken-wow publishes several products from one repo, hence the tag
      # prefixes. A trailing "pre" lets that suite take pre-releases, for
      # addons that only ever publish those (WhatsTraining). A repo of
      # `curseforge:<project id>` takes the newest stable file instead (no
      # tag prefix there); with "pre" it takes betas too, never alphas.
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
        # Herb node memory. Starts empty on Forever: GatherMate2_Data's
        # pre-filled database only ships for retail.
        "gathermate2|Nevcairiel/GatherMate2||^GatherMate2-[0-9.]+\\.zip$"
        # CurseForge/Wago only; one zip for every flavour (its TOC lists 16001).
        "auctionator|curseforge:6124||^Auctionator-[0-9]+\\.zip$"
        # Item sources and drop tables; CurseForge/Wago only (its GitHub repo
        # is just the issue tracker). Ships ItemTree, _Data and _Professions.
        "itemtree|curseforge:1711215||^ItemTree-v[0-9.]+-forever\\.zip$"
        # Cheapest-rep planner for Craftsman's Writs, Waylaid Crates and
        # Merchant's Favor (/writ).
        "inriwritmaster|curseforge:1799394||^InriWritMaster-v[0-9.]+-forever\\.zip$"
        # Profession leveling guide priced from the AH, plus where every
        # recipe drops (Auctionator above is an optional price source).
        "craftersjournal|brunobasas/CraftersJournal|v|^CraftersJournal-v[0-9.]+-forever\\.zip$"
        # RestedXP leveling guides; one zip for every flavour, Forever guides
        # included (its main TOC lists 16001).
        "rxpguides|RestedXP/RXPGuides|v|^RXPGuides-v[0-9.]+\\.zip$"
        # Transmute (plus Mooncloth, Salt Shaker) cooldowns across every alt.
        # Picked over TransmuteTimer, whose TOC only lists Classic Era.
        "pctforever|curseforge:1728486||^ProfessionCooldownTrackerForever-[0-9.]+\\.zip$"
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
          # --force: install anyway and /reload in game afterwards (WoW only
          # reads addon files at login/reload; brand-new folders still need
          # a full client restart to show up).
          if [ "''${1:-}" != "--force" ] && pgrep -fi 'Wow\.exe' >/dev/null; then
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
          # A network or unpack failure skips just that suite (its installed
          # folders are only touched after a clean download), and the run then
          # exits non-zero so Restart= tries again in 30 min.
          failed=()

          for entry in ${lib.escapeShellArgs suites}; do
            IFS='|' read -r suite repo prefix assetRe allowPre <<<"$entry"

            fetched=true
            case "$repo" in
              curseforge:*)
                # CurseForge's own site API: keyless, unlike api.curseforge.com.
                # Its newest stable file is reshaped into a GitHub release so
                # everything below serves both sources.
                project=''${repo#curseforge:}
                release=$(curl -fsSL --retry 3 "https://www.curseforge.com/api/v1/mods/$project/files?pageSize=50&sort=dateCreated&sortDescending=true&removeAlphas=true" |
                  jq -c --arg re "$assetRe" --arg project "$project" --arg pre "$allowPre" \
                    '[.data[] | select(.releaseType == 1 or ($pre == "pre" and .releaseType == 2))
                              | select(.fileName | test($re))][0]
                      | if . == null then null else
                          {tag_name: (.fileName | rtrimstr(".zip")),
                           assets: [{name: .fileName,
                                     url: "https://www.curseforge.com/api/v1/mods/\($project)/files/\(.id)/download"}]}
                        end') || fetched=false
                ;;
              *)
                release=$(curl -fsSL --retry 3 "https://api.github.com/repos/$repo/releases?per_page=100" |
                  jq -c --arg p "$prefix" --arg re "$assetRe" --arg pre "$allowPre" \
                    '[.[] | select(.draft | not) | select($pre == "pre" or (.prerelease | not))
                          | select(.tag_name | startswith($p))
                          | select(any(.assets[]; .name | test($re)))][0]') || fetched=false
                ;;
            esac
            if [ "$fetched" = false ]; then
              echo "$suite: couldn't fetch releases, skipping"
              failed+=("$suite")
              continue
            fi
            tag=$(jq -r '.tag_name' <<<"$release")
            if [ "$tag" = "null" ] || [ -z "$tag" ]; then
              echo "$suite: no release found, skipping"
              continue
            fi
            if [ "$(cat "$state/$suite.tag" 2>/dev/null)" = "$tag" ]; then
              echo "$suite: $tag is current"
              continue
            fi

            # Download through the API asset endpoint, not github.com's
            # /releases/download links: those have 504'd while the API kept
            # serving (2026-11-08).
            url=$(jq -r --arg re "$assetRe" \
              '[.assets[] | select(.name | test($re))][0].url' <<<"$release")
            if [ "$url" = "null" ]; then
              echo "$suite: $tag has no asset matching $assetRe, skipping"
              continue
            fi
            asset=$(jq -r --arg re "$assetRe" \
              '[.assets[] | select(.name | test($re))][0].name' <<<"$release")
            echo "$suite: updating to $tag ($asset)"

            work="$tmp/$suite"
            mkdir -p "$work/x"
            if ! curl -fsSL --retry 3 -H 'Accept: application/octet-stream' -o "$work/$asset" "$url"; then
              echo "$suite: download failed, skipping"
              failed+=("$suite")
              continue
            fi

            sums=$(jq -r '[.assets[] | select(.name == "SHA256SUMS")][0].url' <<<"$release")
            if [ "$sums" != "null" ]; then
              if ! curl -fsSL --retry 3 -H 'Accept: application/octet-stream' -o "$work/SHA256SUMS" "$sums" ||
                ! (cd "$work" && sha256sum -c --ignore-missing SHA256SUMS); then
                echo "$suite: checksum missing or wrong, skipping"
                failed+=("$suite")
                continue
              fi
            fi

            # unzip exits 1 on warnings alone, e.g. a Windows-built zip using
            # backslash separators, which it still unpacks into folders.
            rc=0
            unzip -q "$work/$asset" -d "$work/x" || rc=$?
            if [ "$rc" -gt 1 ]; then
              echo "$suite: couldn't unpack $asset, skipping"
              failed+=("$suite")
              continue
            fi
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
          if [ ''${#failed[@]} -gt 0 ]; then
            echo "Failed this run: ''${failed[*]}"
            exit 1
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

{ self, inputs, ... }: {
  flake.nixosModules.insync = { pkgs, lib, ... }: {
    boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;
    boot.kernel.sysctl."fs.inotify.max_user_instances" = 512;
    boot.kernel.sysctl."fs.inotify.max_queued_events" = 131072;

    nixpkgs.overlays = [
      (final: prev: {
        insync =
          let
            version = "3.9.10.60041";
            debian-dist = "forky_amd64";
            insync-pkg = prev.stdenvNoCC.mkDerivation {
              pname = "insync-pkg";
              inherit version;
              src = prev.fetchurl {
                url = "https://cdn.insynchq.com/builds/linux/${version}/insync_${version}-${debian-dist}.deb";
                hash = "sha256-wi53iGKLQn3OBD1O4l9Dya7njgFk9Km3Xt7OCW2HOvs=";
              };
              nativeBuildInputs = with prev; [
                dpkg
                autoPatchelfHook
                libsForQt5.wrapQtAppsHook
              ];
              buildInputs = with prev; [
                alsa-lib
                nss
                lz4
                libgcrypt
                libthai
                libsForQt5.qtvirtualkeyboard
              ];
              installPhase = ''
                runHook preInstall
                rm -rf usr/lib/insync/PySide2/Qt/qml/
                mkdir -p $out
                cp -R usr/* $out/
                runHook postInstall
              '';
              dontStrip = true;
            };
          in
          prev.buildFHSEnv {
            pname = "insync";
            inherit version;
            targetPkgs =
              pkgs: with pkgs; [
                libudev0-shim
                insync-pkg
                hicolor-icon-theme
              ];
            extraInstallCommands = ''
              cp -rsHf "${insync-pkg}"/share $out/
            '';
            runScript = prev.writeShellScript "insync-wrapper.sh" ''
              export XKB_CONFIG_ROOT=${prev.xkeyboard_config}/share/X11/xkb/
              exec /usr/lib/insync/insync "$@"
            '';
            unshareUser = false;
            unshareIpc = false;
            unsharePid = false;
            unshareNet = false;
            unshareUts = false;
            unshareCgroup = false;
            dieWithParent = true;
            meta = prev.insync.meta;
          };
      })
    ];

    environment.systemPackages = with pkgs; [
      insync
      insync-nautilus
    ];
  };

  # Desktop notifications for files arriving in the synced tree.
  #
  # Insync's own notifications are dead as of 3.9.10: it drives them through
  # `notify2`, which needs dbus-python's native `_dbus_bindings` module, and the
  # PyInstaller bundle ships neither that nor libdbus-glib. The import fails at
  # startup and every notification is dropped silently —
  #   ERROR [platui_impl:display_notification:82] Cannot initialize notifications.
  # in ~/.config/Insync/out.txt. Nothing we can add to the FHS env fixes it (the
  # frozen interpreter won't load an external module built for its exact 3.9
  # ABI), so we watch the tree ourselves.
  #
  # Cost, measured on styx over the full 21k-directory share: watches cost ~94
  # bytes each (≈2 MB of kernel slab), the watcher idles at 0 CPU, and setup is
  # sub-second warm. Insync already holds watches on the same directories, so
  # the inodes are pinned regardless and our marks are the only new cost.
  flake.nixosModules.insyncNotify =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.insyncNotify;

      # Runs from the graphical session rather than a systemd user service so it
      # inherits the session bus the notification daemon is on (same reasoning as
      # myHyprland.extraStartupExec's own documentation).
      watcher = pkgs.writeShellApplication {
        name = "insync-notify";
        runtimeInputs = with pkgs; [
          inotify-tools
          libnotify
          coreutils
        ];
        text = ''
          window=${toString cfg.batchSeconds}
          paths=(${lib.concatMapStringsSep " " lib.escapeShellArg cfg.paths})

          # None of these mean "a file arrived": dotfiles (LibreOffice's
          # .~lock.<name>#), Word owner files (~$name.docx), Windows droppings.
          exclude='/(\.[^/]*|~\$[^/]*|thumbs\.db|desktop\.ini)$'

          declare -A counts=()
          names=()
          total=0

          record() {
            local path="$1" dir
            dir=$(dirname "$path")
            counts["$dir"]=$(( ''${counts["$dir"]:-0} + 1 ))
            # Only the first few names are ever shown; don't grow this unbounded
            # during a bulk sync.
            if [ "''${#names[@]}" -lt 5 ]; then
              names+=( "$(basename "$path")" )
            fi
            total=$(( total + 1 ))
          }

          flush() {
            if [ "$total" -eq 0 ]; then
              return 0
            fi

            local dir first_dir="" n_dirs=0 plural="" summary body shown=0
            for dir in "''${!counts[@]}"; do
              n_dirs=$(( n_dirs + 1 ))
              if [ -z "$first_dir" ]; then first_dir="$dir"; fi
            done
            if [ "$total" -gt 1 ]; then plural="s"; fi

            if [ "$n_dirs" -eq 1 ]; then
              summary="$total new file$plural in $(basename "$first_dir")"
              body=$(printf '%s\n' "''${names[@]}")
              if [ "$total" -gt 5 ]; then
                body="$body"$'\n'"…and $(( total - 5 )) more"
              fi
            else
              summary="$total new file$plural in $n_dirs folders"
              body=""
              for dir in "''${!counts[@]}"; do
                if [ "$shown" -ge 6 ]; then
                  body="$body…and $(( n_dirs - shown )) more folders"$'\n'
                  break
                fi
                body="$body''${counts[$dir]} × $(basename "$dir")"$'\n'
                shown=$(( shown + 1 ))
              done
            fi

            # A failure here means no daemon is up yet (we start alongside the
            # shell); drop the batch rather than taking the watcher down with it.
            notify-send -a Insync -i insync-folder -u low "$summary" "$body" || true

            unset counts
            declare -gA counts=()
            names=()
            total=0
          }

          # close_write covers files written in place, moved_to covers Insync's
          # download-to-temp-then-rename. Nothing fires for the initial walk, so
          # there's no burst of notifications at login.
          exec 3< <(inotifywait -m -r -q --format '%w%f' \
            -e close_write -e moved_to \
            --excludei "$exclude" \
            "''${paths[@]}")
          iw_pid=$!

          # Without this, killing the watcher (session restart) orphans
          # inotifywait still holding every watch it established — 21k of them on
          # styx, leaked again on each restart.
          cleanup() {
            kill "$iw_pid" 2>/dev/null || true
          }
          trap cleanup EXIT INT TERM HUP

          while IFS= read -r path <&3; do
            record "$path"
            # Keep absorbing events until the tree goes quiet for $window
            # seconds, so one sync produces one notification. The count cap stops
            # a large sync from deferring the batch indefinitely.
            while [ "$total" -lt 200 ] && IFS= read -r -t "$window" more <&3; do
              record "$more"
            done
            flush
          done
        '';
      };
    in
    {
      options.insyncNotify = {
        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "/mnt/nvme3/share" ];
          description = ''
            Directories to watch recursively for new files. Empty (the default)
            leaves the watcher out of the session entirely, so the module is
            inert on hosts that sync nothing locally.
          '';
        };

        batchSeconds = lib.mkOption {
          type = lib.types.ints.positive;
          default = 10;
          description = ''
            How long the tree must stay quiet before a batch is announced. One
            notification per burst rather than one per file.
          '';
        };
      };

      config = lib.mkIf (cfg.paths != [ ]) {
        myHyprland.extraStartupExec = [ (lib.getExe watcher) ];
        environment.systemPackages = [ watcher ];
      };
    };
}

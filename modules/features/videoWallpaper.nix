{ ... }:
{
  # Animated wallpaper via mpvpaper — mpv rendered onto a wlr-layer-shell
  # surface on the background layer.
  #
  # Decode runs on the GPU: with hwdec=vaapi a 1440p60 clip costs ~3.6% of one
  # core steady-state, against ~75% with software decode. That residual is not
  # decode — it is mpv's GL compositing path submitting a frame to the Wayland
  # surface every vblank, which is inherently CPU-side. If the wallpaper ever
  # starts eating a whole core, hwdec silently fell back to software; check
  # `hwdec-current` over the IPC socket (see mpvOptions below).
  #
  # Noctalia's own wallpaper is disabled in noctalia.nix: both draw on layer 0
  # and the one that maps *last* wins, which is a race at login.
  flake.nixosModules.videoWallpaper =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.myVideoWallpaper;

      # An empty pattern list must never match; `$^` is unmatchable.
      orPatterns = pats: if pats == [ ] then "$^" else lib.concatStringsSep "|" pats;

      classRe = orPatterns cfg.pauseClassPatterns;
      titleRe = orPatterns cfg.pauseTitlePatterns;
      tagsJson = builtins.toJSON cfg.pauseTags;

      videoExtRe = ".*\\.(mp4|mkv|webm|mov|m4v|avi|gif)";

      # Shell-expanded at runtime in both scripts, so they agree on one path.
      ipcSock = ''"''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/video-wallpaper.sock"'';

      # Skip to the next video without waiting out `interval`. Bound to the key
      # that used to open Noctalia's wallpaper panel, which does nothing now
      # that Noctalia's wallpaper is off.
      wallpaperNext = pkgs.writeShellApplication {
        name = "video-wallpaper-next";
        runtimeInputs = with pkgs; [
          socat
          libnotify
          coreutils
        ];
        text = ''
          ipc_sock=${ipcSock}
          # No socket means the wallpaper is stopped — which is the normal state
          # during a game, not an error worth a popup on every keypress.
          if [ ! -S "$ipc_sock" ]; then
            notify-send -a Wallpaper -u low "Wallpaper not running" \
              "Nothing to skip — it stops while a game is up." || true
            exit 0
          fi
          printf '{"command":["playlist-next"]}\n' | socat - "$ipc_sock" >/dev/null
        '';
      };

      # Runs from the graphical session rather than a systemd user service so it
      # inherits WAYLAND_DISPLAY and HYPRLAND_INSTANCE_SIGNATURE (same reasoning
      # as myHyprland.extraStartupExec's own documentation).
      wallpaper = pkgs.writeShellApplication {
        name = "video-wallpaper";
        runtimeInputs = with pkgs; [
          mpvpaper
          socat
          inotify-tools
          jq
          findutils
          coreutils
          libnotify
          config.programs.hyprland.package # hyprctl
        ];
        text = ''
          dir=${lib.escapeShellArg cfg.directory}
          mkdir -p "$dir"

          ipc_sock=${ipcSock}
          mpv_pid=""

          # mpvpaper is run *without* -f so this script owns the pid directly.
          # With -f it double-forks and the pid you get back is not the process
          # holding the surface — killing it leaves an orphan still rendering.
          # (Note also that nixpkgs wraps the binary, so /proc/<pid>/comm is
          # ".mpvpaper-wrapp" and `pkill -x mpvpaper` matches nothing.)
          start() {
            if [ -n "$mpv_pid" ] && kill -0 "$mpv_pid" 2>/dev/null; then
              return 0
            fi
            if [ -z "$(find -L "$dir" -maxdepth 1 -type f -regextype posix-extended \
                        -iregex ${lib.escapeShellArg videoExtRe} -print -quit)" ]; then
              return 0
            fi
            # The IPC socket is appended here rather than left to mpvOptions:
            # video-wallpaper-next has to know the path, and a user override of
            # mpvOptions would otherwise silently break that command.
            rm -f "$ipc_sock"
            # mpv expands a directory into a playlist; -n makes mpvpaper advance
            # it and adds "loop loop-playlist" itself.
            mpvpaper -n ${toString cfg.interval} \
              -o "${cfg.mpvOptions} input-ipc-server=$ipc_sock" \
              ${lib.escapeShellArg cfg.output} "$dir" &
            mpv_pid=$!
          }

          stop() {
            if [ -z "$mpv_pid" ]; then
              return 0
            fi
            kill "$mpv_pid" 2>/dev/null || true
            wait "$mpv_pid" 2>/dev/null || true
            mpv_pid=""
            rm -f "$ipc_sock"
          }

          # Stop outright rather than pausing. mpvpaper's own -p/-s are
          # documented as "might not work as intended" and do not fire reliably
          # under Hyprland, and a paused mpv still holds its VAAPI surfaces and
          # ~160MB RSS — which is exactly what we want back during a game.
          covered() {
            hyprctl -j clients | jq -e \
              --arg class ${lib.escapeShellArg classRe} \
              --arg title ${lib.escapeShellArg titleRe} \
              --argjson tags ${lib.escapeShellArg tagsJson} \
              --argjson fs ${if cfg.pauseOnFullscreen then "true" else "false"} '
                any(.[];
                     ((.class // "") | test($class))
                  or ((.title // "") | test($title))
                  or (((.tags // []) - $tags) != (.tags // []))
                  or ($fs and (((.fullscreen // 0) != 0) or ((.fullscreenClient // 0) != 0)))
                )' >/dev/null
          }

          sync_state() {
            if covered; then stop; else start; fi
          }

          reload() {
            stop
            sync_state
          }

          socat_pid=""
          inotify_pid=""

          cleanup() {
            stop
            # Don't orphan the watchers: inotifywait would keep holding its
            # watch, and socat its socket, across every session restart.
            for p in "$socat_pid" "$inotify_pid"; do
              if [ -n "$p" ]; then kill "$p" 2>/dev/null || true; fi
            done
          }
          # cleanup must not be the signal handler itself: bash runs the handler
          # and then *resumes* the read loop, so a plain `trap cleanup TERM`
          # tears down mpvpaper and the watchers while leaving this script alive
          # and unable to rebuild them. Signal handlers exit; EXIT does the work.
          trap cleanup EXIT
          trap 'exit 0' INT TERM HUP

          # Merge Hyprland's event socket and a watch on the wallpaper directory
          # into one fd. Opened read-write so the loop never sees EOF, and read
          # from in *this* shell — a pipeline or process substitution would put
          # the loop in a subshell where $mpv_pid can't survive an iteration.
          fifo=$(mktemp -u -t video-wallpaper.XXXXXX)
          mkfifo "$fifo"
          exec 3<>"$fifo"
          rm -f "$fifo"

          # PoE is force-fullscreened by a window rule with fullscreen_state
          # "0 2", i.e. client-side only — so the "fullscreen" event fires and
          # .fullscreenClient is what actually reflects it, not .fullscreen.
          sock="''${XDG_RUNTIME_DIR}/hypr/''${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
          socat -u UNIX-CONNECT:"$sock" - >&3 &
          socat_pid=$!

          # mpv expands the directory into a playlist once, at launch, so a file
          # dropped in afterwards stays invisible until mpvpaper restarts — and
          # a nixos-rebuild won't do it, since hyprland.start only fires at
          # login. Watch the directory and restart ourselves instead.
          inotifywait -m -q -e close_write -e moved_to -e delete -e moved_from \
            --format 'wallpaperdir>>%f' "$dir" >&3 &
          inotify_pid=$!

          sync_state

          while IFS= read -r line <&3; do
            case "$line" in
              wallpaperdir\>\>*)
                # Absorb the rest of the burst — one copy fires several events,
                # and a large file lands well after the first one. Window events
                # swallowed here cost nothing: reload re-evaluates anyway.
                while IFS= read -r -t ${toString cfg.reloadDebounce} _ <&3; do :; done
                reload
                ;;
              openwindow\>\>* | closewindow\>\>* | fullscreen\>\>* | changefloatingmode\>\>*)
                sync_state
                ;;
            esac
          done
        '';
      };
    in
    {
      options.myVideoWallpaper = {
        enable = lib.mkEnableOption "animated video wallpaper via mpvpaper";

        directory = lib.mkOption {
          type = lib.types.str;
          example = "/home/swin/Videos/Wallpapers";
          description = ''
            Directory of video files to cycle through. Created if absent. While
            it holds no playable file the wallpaper simply does not start, and
            since Noctalia's static wallpaper is disabled the background stays
            black — drop at least one video in.
          '';
        };

        output = lib.mkOption {
          type = lib.types.str;
          default = "*";
          example = "DP-3";
          description = ''
            Output to render on. "*" covers every connected output (mpvpaper
            draws the same playlist on each). Use `mpvpaper -d` to list names.
          '';
        };

        interval = lib.mkOption {
          type = lib.types.ints.positive;
          default = 900;
          description = "Seconds before advancing to the next video in the directory.";
        };

        reloadDebounce = lib.mkOption {
          type = lib.types.ints.positive;
          default = 3;
          description = ''
            Seconds of quiet required after a change in `directory` before the
            wallpaper restarts. Stops a multi-second file copy from causing one
            restart per write; raise it if you drop very large files in over a
            slow link.
          '';
        };

        mpvOptions = lib.mkOption {
          type = lib.types.str;
          default = "no-audio hwdec=vaapi panscan=1.0";
          description = ''
            Options forwarded to mpv. hwdec=vaapi is the AMD path and is
            deliberately explicit — "auto-safe" can fall back to software decode
            silently, which costs ~75% of a core instead of ~3.6%. panscan=1.0
            crops to fill rather than letterboxing, matching the "crop" fill
            mode Noctalia used. Append input-ipc-server=/tmp/mpvpaper.sock to
            inspect a running instance with socat.
          '';
        };

        pauseTags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "poe" ];
          description = ''
            Hyprland window tags that stop the wallpaper while present. Reuses
            the tags already assigned by window rules in hyprland.nix.
          '';
        };

        pauseClassPatterns = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "^steam_app_[0-9]+$"
            "^gamescope$"
            "^shadps4"
            "^BeamNG"
          ];
          description = "Regexes matched against window class; any match stops the wallpaper.";
        };

        pauseTitlePatterns = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "^Path of Exile( 2)?$" ];
          description = "Regexes matched against window title; any match stops the wallpaper.";
        };

        pauseOnFullscreen = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Also stop whenever any window is fullscreen (server- or client-side).
            The wallpaper is fully hidden then regardless of what the window is,
            so there is nothing to render.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [
          pkgs.mpvpaper
          wallpaper
          wallpaperNext
        ];
        myHyprland.extraStartupExec = [ (lib.getExe wallpaper) ];
        myHyprland.extraBindsLua = ''
          -- Wallpaper: skip to the next video (was Noctalia's wallpaper panel).
          hl.bind(mod .. " + semicolon", hl.dsp.exec_cmd("${lib.getExe wallpaperNext}"))
        '';
      };
    };
}

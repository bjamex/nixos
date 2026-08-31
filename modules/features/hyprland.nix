{ self, inputs, ... }:
{
  flake.nixosModules.hyprland =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      # Focus an existing Thunderbird window if one is open, else launch it.
      # Ported from niri-base.nix (niri msg -> hyprctl).
      thunderbirdFocusOrOpen = pkgs.writeShellScript "thunderbird-focus-or-open" ''
        addr=$(${config.programs.hyprland.package}/bin/hyprctl -j clients | \
          ${lib.getExe pkgs.jq} -r '[.[] | select(.class == "thunderbird")] | .[0].address // empty')
        if [ -n "$addr" ]; then
          ${config.programs.hyprland.package}/bin/hyprctl dispatch focuswindow "address:$addr"
        else
          thunderbird
        fi
      '';

      # Toggle mic mute with a sound cue via wpctl's mute-flag path — the same
      # call widget.mic_button uses in noctalia.nix. This flips *only* the mute
      # flag: mic volume stays pinned at 150% and the output sink is never
      # touched. We deliberately avoid `noctalia msg mic-mute`: that internal
      # path copies the live mic volume onto the default speaker sink, so with
      # mic at 150% + overdrive the speakers get slammed to 150% on (un)mute.
      # Trade-off: no dedicated Noctalia mic OSD popup, but the bind is correct.
      micMuteToggle = pkgs.writeShellScript "mic-mute-toggle" ''
        ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ${lib.getExe' pkgs.pipewire "pw-play"} ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga
      '';

      # Toggle global window transparency: flip active/inactive opacity between
      # the themed 0.95 and fully opaque 1.0 (e.g. for accurate photo editing).
      transparencyToggle = pkgs.writeShellScript "transparency-toggle" ''
        hyprctl=${config.programs.hyprland.package}/bin/hyprctl
        cur=$("$hyprctl" getoption decoration:active_opacity -j | ${lib.getExe pkgs.jq} -r '.float')
        # Lua-config Hyprland rejects `keyword`; runtime changes go via `eval`.
        # Opaque when current >= 0.99, so toggle to transparent; else opaque.
        if ${lib.getExe' pkgs.gawk "awk"} "BEGIN { exit !($cur >= 0.99) }"; then
          o=0.95
        else
          o=1.0
        fi
        "$hyprctl" eval "hl.config({ decoration = { active_opacity = $o, inactive_opacity = $o } })"
      '';

      # Toggle a simple screen recording with wf-recorder. First press asks
      # slurp for a region and starts recording to ~/Videos/Recordings; a second
      # press SIGINTs the running wf-recorder, which finalizes the mp4 cleanly.
      screenRecordToggle = pkgs.writeShellScript "screen-record-toggle" ''
        notify=${lib.getExe' pkgs.libnotify "notify-send"}
        # If a recording is already running, stop it (SIGINT flushes the file).
        if ${lib.getExe' pkgs.procps "pkill"} -INT -x wf-recorder; then
          "$notify" "Screen recording" "Stopped — saved to ~/Videos/Recordings"
          exit 0
        fi
        dir="$HOME/Videos/Recordings"
        mkdir -p "$dir"
        file="$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"
        geom=$(${lib.getExe pkgs.slurp}) || exit 1
        "$notify" "Screen recording" "Recording started"
        ${lib.getExe pkgs.wf-recorder} -g "$geom" -f "$file"
      '';

      # Region OCR — pick a region, pipe the raw PNG straight into tesseract and
      # put the recognised text on the clipboard. Nothing touches disk. Bound to
      # SUPER+CTRL+Print, alongside the plain Print screenshot.
      ocrRegion =
        let
          # eng only: the unqualified package pulls in every language pack.
          tesseractEng = pkgs.tesseract.override { enableLanguages = [ "eng" ]; };
        in
        pkgs.writeShellScript "ocr-region" ''
          notify=${lib.getExe' pkgs.libnotify "notify-send"}
          geom=$(${lib.getExe pkgs.slurp}) || exit 0
          # tesseract takes the PNG on stdin ("-") and writes plain text to stdout.
          text=$(${lib.getExe pkgs.grim} -g "$geom" -t png - | ${tesseractEng}/bin/tesseract - - 2>/dev/null)
          if [ -z "$(printf '%s' "$text" | tr -d '[:space:]')" ]; then
            "$notify" "OCR" "No text found in that selection"
            exit 1
          fi
          printf '%s' "$text" | ${pkgs.wl-clipboard}/bin/wl-copy
          "$notify" "OCR" "Copied $(printf '%s' "$text" | wc -c) characters to the clipboard"
        '';

      # Shadowplay-style rolling replay buffer via gpu-screen-recorder. Started
      # at login (see hyprland.start); it keeps the last 5 min encoded in RAM
      # (VAAPI on this AMD GPU, near-zero cost) and writes nothing until saved.
      # Heads-up: the in-RAM buffer costs a few hundred MB — tune -r/-q if needed.
      gpuReplayDaemon = pkgs.writeShellScript "gpu-replay-daemon" ''
        dir="$HOME/Videos/Replays"
        mkdir -p "$dir"
        exec ${lib.getExe pkgs.gpu-screen-recorder} \
          -w screen \
          -f 60 \
          -a default_output \
          -c mp4 \
          -r 300 \
          -o "$dir"
      '';

      # Quit the session without shredding config files. Some apps only persist
      # state on a clean quit: darktable rewrites ~/.config/darktable/darktablerc
      # from memory in dt_conf_cleanup, and _conf_save() truncates the file
      # (fopen "wb") *before* writing it — so a SIGKILL at session teardown
      # leaves it 0 bytes and every preference is gone. Ask those windows to
      # close (a Wayland close request is a normal quit), wait for them to
      # actually exit, then tear down Hyprland.
      gracefulExit = pkgs.writeShellScript "hypr-graceful-exit" ''
        hyprctl=${config.programs.hyprland.package}/bin/hyprctl
        jq=${lib.getExe pkgs.jq}

        # Window classes to close politely first. Add classes here as needed.
        want='["org.darktable.darktable"]'

        clients=$("$hyprctl" -j clients)
        sel='.[] | select(.class as $c | $want | index($c))'
        addrs=$(printf '%s' "$clients" | "$jq" -r --argjson want "$want" "$sel | .address")
        pids=$(printf '%s' "$clients" | "$jq" -r --argjson want "$want" "$sel | .pid")

        for addr in $addrs; do
          "$hyprctl" dispatch closewindow "address:$addr"
        done

        # Give them up to 15s to write their config, then exit regardless — a
        # stuck app must never leave the session un-exitable.
        for _ in $(seq 1 150); do
          alive=""
          for pid in $pids; do
            kill -0 "$pid" 2>/dev/null && alive=1
          done
          [ -n "$alive" ] || break
          sleep 0.1
        done

        "$hyprctl" dispatch exit
      '';

      # Flush the current 5-min buffer to disk. gpu-screen-recorder saves the
      # replay on SIGUSR1. Match with -f: its /proc comm is truncated to 15
      # chars, so -x against the full name would never hit.
      gpuReplaySave = pkgs.writeShellScript "gpu-replay-save" ''
        notify=${lib.getExe' pkgs.libnotify "notify-send"}
        if ${lib.getExe' pkgs.procps "pkill"} -USR1 -f gpu-screen-recorder; then
          "$notify" "Replay saved" "Last 5 min → ~/Videos/Replays"
        else
          "$notify" "Replay buffer not running" "gpu-screen-recorder is not active"
        fi
      '';
    in
    {
      options.myHyprland.monitorLua = lib.mkOption {
        type = lib.types.lines;
        default = ''hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })'';
        description = "Per-host hl.monitor(...) Lua calls. Default auto-detects all outputs.";
      };

      options.myHyprland.autoSuspend = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether hypridle suspends the machine after the idle timeout. Disable on always-on desktops.";
      };

      options.myHyprland.idleLock = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether hypridle locks the screen after the idle timeout. Disable on trusted always-on desktops.";
      };

      options.myHyprland.extraBindsLua = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Extra `hl.bind(...)` Lua appended after the built-in binds, so a
          feature module can own its own keybind instead of this file carrying a
          bind for something it doesn't otherwise know about. `mod` is in scope.
        '';
      };

      options.myHyprland.extraStartupExec = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Extra commands (store paths or plain executables) run via `hl.exec_cmd`
          on `hyprland.start`, alongside the built-ins below. Use this instead of
          editing the Lua block directly so other feature modules (e.g. the voice
          satellite) can hook into session startup and inherit Hyprland's
          WAYLAND_DISPLAY / HYPRLAND_INSTANCE_SIGNATURE — a systemd user service
          on default.target does not have these.
        '';
      };

      config = {
        programs.hyprland = {
          enable = true;
          # PR #14897 was carried as a patch when Hyprland was on 0.55.x; it is
          # now merged upstream (0.55.3+), so the override was dropped — applying
          # it again fails with "previously applied".
        };

        xdg.portal.config.hyprland = {
          default = [
            "hyprland"
            "gtk"
          ];
          "org.freedesktop.impl.portal.FileChooser" = "gtk";
        };

        environment.systemPackages = with pkgs; [
          hyprlock
          hypridle
          grimblast
          wf-recorder # simple Wayland screen recorder (see screenRecordToggle bind)
          gpu-screen-recorder # GPU-encoded capture + replay buffer (see gpuReplay* )
          slurp # region picker for wf-recorder / grimblast
          wl-clipboard # grimblast copy* needs wl-copy
          inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];

        hjem.users.swin.files = {
          ".config/hypr/hyprland.lua".text = ''
            -- Monitor (host-specific; see myHyprland.monitorLua)
            ${config.myHyprland.monitorLua}

            -- Startup
            hl.on("hyprland.start", function()
              -- xdg-desktop-portal 1.22 added Requisite=graphical-session.target
              -- to its unit: the portal now refuses to start unless that target
              -- is already active, where 1.20 D-Bus activated regardless. The
              -- plain start-hyprland session (login.nix keeps it over the uwsm
              -- one, whose bindpid handshake fails under SDDM) never activates
              -- it, so after the 2026-08-16 bump nothing had a ScreenCast
              -- backend — Discord streaming, OBS and screenshots all silently
              -- lost their portal. This shipped-but-unwired NixOS target
              -- BindsTo graphical-session.target, which pulls it up.
              hl.exec_cmd("systemctl --user start nixos-fake-graphical-session.target")
              hl.exec_cmd("noctalia")
              hl.exec_cmd("${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1")
              hl.exec_cmd("insync start")
              -- wl-clip-persist removed: it drained every Wayland selection, and
              -- Hyprland leaks a pipe fd per transfer. EE2's price-check hotkey
              -- (synthetic Ctrl+C) fired these rapidly in PoE2, exhausting
              -- Hyprland's RLIMIT_NOFILE (524288) → 40% CPU busy-loop + sluggish
              -- desktop. See exiled-exchange.nix "synthetic copy" comment.
              hl.exec_cmd("hypridle")
              hl.exec_cmd("${gpuReplayDaemon}")
              ${lib.concatMapStringsSep "\n              " (
                cmd: ''hl.exec_cmd("${cmd}")''
              ) config.myHyprland.extraStartupExec}
            end)

            -- Animation curves
            hl.curve("snap",   { type = "bezier", points = {{0.25, 1.0}, {0.5, 1.0}} })
            hl.curve("linear", { type = "bezier", points = {{0.0,  0.0}, {1.0, 1.0 }} })

            hl.animation({ leaf = "windows",     enabled = true, speed = 2, bezier = "snap"   })
            hl.animation({ leaf = "windowsIn",   enabled = true, speed = 2, bezier = "snap",   style = "popin 80%" })
            hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2, bezier = "snap",   style = "popin 80%" })
            hl.animation({ leaf = "windowsMove", enabled = true, speed = 2, bezier = "snap"   })
            hl.animation({ leaf = "workspaces",  enabled = true, speed = 2, bezier = "snap"   })
            hl.animation({ leaf = "border",      enabled = true, speed = 2, bezier = "linear" })
            hl.animation({ leaf = "fade",        enabled = true, speed = 2, bezier = "linear" })
            hl.animation({ leaf = "fadeDim",     enabled = true, speed = 2, bezier = "linear" })

            -- Configuration
            hl.config({
              general = {
                gaps_in     = 3,
                gaps_out    = 7,
                border_size = 2,
                -- Hand-copied from customPalettes.doomed in noctalia.nix (mPrimary /
                -- mOutline): Hyprland has a Noctalia template, but this config is
                -- a Nix-generated read-only hyprland.lua, so the template's hook
                -- could not write to it. Update both together.
                col = {
                  active_border   = "rgba(51afefff)",
                  inactive_border = "rgba(3f444aff)",
                },
                layout = "dwindle",
              },
              decoration = {
                rounding         = 0,
                active_opacity   = 0.95,
                inactive_opacity = 0.95,
                fullscreen_opacity = 1.0,
                blur = {
                  enabled  = true,
                  passes   = 2,
                  noise    = 0.02,
                  vibrancy = 0.1696,
                },
                shadow = {
                  enabled = false,
                },
              },
              animations = {
                enabled = true,
              },
              dwindle = {
                preserve_split = true,
                force_split    = 2,
              },
              misc = {
                force_default_wallpaper  = 0,
                disable_hyprland_logo    = true,
                disable_splash_rendering = true,
                mouse_move_enables_dpms  = true,
                key_press_enables_dpms   = true,
                -- Honor app activation requests (e.g. EE2's price-check overlay grabbing
                -- focus when it pops up) so it doesn't instantly hide-on-blur on a tap.
                focus_on_activate        = true,
              },
              input = {
                kb_layout    = "us,ua",
                follow_mouse = 1,
                accel_profile = "flat",
                touchpad = {
                  natural_scroll = true,
                  tap_to_click   = true,
                },
              },
            })

            -- Window rules

            -- Path of Exile
            hl.window_rule({ match = { title = "Path of Exile( 2)?" },        tag = "+poe" })
            hl.window_rule({ match = { class = "steam_app_(238960|2694490)" }, tag = "+poe" })
            hl.window_rule({ match = { tag = "poe" },
              workspace       = "5",
              fullscreen      = true,
              fullscreen_state = "0 2",
              idle_inhibit    = "always",
              rounding        = 0, -- square corners: game fills to the edge, no bg peeking through
            })

            -- PoE overlay tools
            hl.window_rule({ match = { title = "Exiled Exchange 2" },   tag = "+overlay" })
            hl.window_rule({ match = { class = "awakened-poe-trade" },  tag = "+overlay" })
            -- Scalpel (verify class/title with `hyprctl clients`; adjust if it differs)
            hl.window_rule({ match = { class = "Scalpel" },             tag = "+overlay" })
            hl.window_rule({ match = { title = "Scalpel" },             tag = "+overlay" })
            -- PoE Campaign Copilot (Tauri) — main window's title is always
            -- exactly "PoE Campaign Copilot" (Settings/dialogs retitle, this
            -- one doesn't), so this full-match won't catch a browser tab.
            -- Park it on ws5 over the (fake-)fullscreen game, no focus steal.
            hl.window_rule({ match = { title = "PoE Campaign Copilot" },  tag = "+overlay" })
            hl.window_rule({ match = { title = "PoE Campaign Copilot" },
              workspace = "5",
              float     = true,
              no_focus  = true,
              -- Bottom-centred, just above PoE's skill/XP bar. This Hyprland's
              -- move parser has no window-height token, so we can't bottom-
              -- anchor; instead pin the top-left low (y = monitor_h - 200) and
              -- let content grow downward. 200 clears the bottom UI for typical
              -- area-info; raise it if a tall zone list overflows. x = (2560 -
              -- ~1006 width)/2 centres on DP-3. Applied on window open — relaunch
              -- the overlay after changing.
              move      = "777 monitor_h-200",
            })
            hl.window_rule({ match = { tag = "overlay" },
              float      = true,
              no_blur    = true,
              no_shadow  = true,
              border_size = 0,
            })

            -- Calculator — float at a sane size instead of full monitor height
            hl.window_rule({ match = { class = "org.gnome.Calculator" }, float = true, size = { 360, 540 }, center = true })

            -- Steam notifications — float, no focus steal
            hl.window_rule({ match = { title = "notificationtoasts_.*_desktop" }, float = true, no_focus = true })

            -- Keybinds
            local mod = "SUPER"

            -- Apps
            hl.bind(mod .. " + Return",       hl.dsp.exec_cmd("kitty herdr"))
            hl.bind(mod .. " + N",            hl.dsp.exec_cmd("kitty nvim"))
            hl.bind(mod .. " + W",            hl.dsp.window.close())
            hl.bind(mod .. " + Space",        hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
            hl.bind(mod .. " + SHIFT + F",    hl.dsp.exec_cmd("nautilus"))
            hl.bind(mod .. " + B",            hl.dsp.exec_cmd("helium"))
            hl.bind(mod .. " + F",            hl.dsp.exec_cmd("kitty yazi"))
            hl.bind(mod .. " + E",            hl.dsp.exec_cmd("${thunderbirdFocusOrOpen}"))
            hl.bind(mod .. " + D",            hl.dsp.exec_cmd("flatpak run com.discordapp.Discord"))
            hl.bind(mod .. " + SHIFT + V",    hl.dsp.exec_cmd("vpn-toggle"))
            hl.bind(mod .. " + SHIFT + F12",  hl.dsp.exec_cmd("${gracefulExit}"))
            hl.bind("Print",                  hl.dsp.exec_cmd("mkdir -p ~/Pictures/Screenshots && grimblast copysave area ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"))
            hl.bind(mod .. " + CTRL + Print", hl.dsp.exec_cmd("${ocrRegion}"))
            hl.bind(mod .. " + SHIFT + R",    hl.dsp.exec_cmd("${screenRecordToggle}"))
            hl.bind(mod .. " + SHIFT + S",    hl.dsp.exec_cmd("${gpuReplaySave}"))

            -- Window management
            hl.bind(mod .. " + SHIFT + M", hl.dsp.window.fullscreen({ type = "fullscreen" }))
            hl.bind(mod .. " + M",         hl.dsp.window.fullscreen({ type = "maximize" }))
            hl.bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
            hl.bind(mod .. " + C",         hl.dsp.exec_cmd("gnome-calculator"))
            hl.bind(mod .. " + O",         hl.dsp.exec_cmd("${transparencyToggle}"))
            hl.bind(mod .. " + H",         hl.dsp.exec_cmd("hyprctl dispatch resizeactive -640 0"))

            -- Workspace navigation
            hl.bind(mod .. " + left",  hl.dsp.focus({ workspace = "e-1" }))
            hl.bind(mod .. " + right", hl.dsp.focus({ workspace = "e+1" }))
            hl.bind(mod .. " + up",    hl.dsp.focus({ workspace = "e+1" }))
            hl.bind(mod .. " + down",  hl.dsp.focus({ workspace = "e-1" }))

            -- Move window
            hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
            hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
            hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
            hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))

            -- Numbered workspaces
            for i = 1, 9 do
              hl.bind(mod .. " + " .. i,            hl.dsp.focus({ workspace = i }))
              hl.bind(mod .. " + SHIFT + " .. i,    hl.dsp.window.move({ workspace = i }))
            end

            -- Mouse
            hl.bind(mod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
            hl.bind(mod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })
            hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
            hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

            -- Media / brightness (locked = works on lock screen)
            hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("pamixer -t"),                    { locked = true })
            hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("pamixer -d 5"),                  { locked = true })
            hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("pamixer -i 5"),                  { locked = true })
            hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("${micMuteToggle}"),              { locked = true })
            hl.bind("KP_Subtract",           hl.dsp.exec_cmd("${micMuteToggle}"),              { locked = true })
            hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"),          { locked = true })
            hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"),          { locked = true })

            -- Media controls drive jellyfin-tui and YouTube Music (Helium/chromium) together via MPRIS.
            -- Plain playerctl only hits one player, so send to both explicitly.
            local pctl       = "${lib.getExe pkgs.playerctl}"
            local play_pause = pctl .. " -p jellyfin-tui play-pause; " .. pctl .. " -p chromium play-pause"
            local next_song  = pctl .. " -p jellyfin-tui next; "       .. pctl .. " -p chromium next"
            local prev_song  = pctl .. " -p jellyfin-tui previous; "   .. pctl .. " -p chromium previous"

            hl.bind("XF86AudioPlay",          hl.dsp.exec_cmd(play_pause), { locked = true })
            hl.bind("XF86AudioNext",          hl.dsp.exec_cmd(next_song),  { locked = true })
            hl.bind("XF86AudioPrev",          hl.dsp.exec_cmd(prev_song),  { locked = true })
            -- Chords for keyboards without media keys
            hl.bind(mod .. " + backslash",    hl.dsp.exec_cmd(play_pause))
            hl.bind(mod .. " + bracketright", hl.dsp.exec_cmd(next_song))
            hl.bind(mod .. " + bracketleft",  hl.dsp.exec_cmd(prev_song))

            ${config.myHyprland.extraBindsLua}
          '';

          ".config/hypr/hypridle.conf".text = ''
            general {
              lock_cmd         = hyprlock
              before_sleep_cmd = hyprlock
              after_sleep_cmd  = hyprctl dispatch dpms on
            }

            ${lib.optionalString config.myHyprland.idleLock ''
              listener {
                timeout  = 300
                on-timeout = hyprlock
              }''}
            ${lib.optionalString config.myHyprland.autoSuspend ''

              listener {
                timeout  = 1800
                on-timeout = systemctl suspend
              }''}
          '';

          ".config/hypr/hyprlock.conf".text = ''
            background {
              monitor =
              color   = rgba(28, 30, 30, 1.0)
              blur_passes = 2
              blur_size   = 7
            }

            input-field {
              monitor          =
              size             = 300, 50
              outline_thickness = 2
              outer_color      = rgb(51afef)
              inner_color      = rgb(282c34)
              font_color       = rgb(fffcf8)
              fade_on_empty    = true
              placeholder_text =
              hide_input       = false
              position         = 0, -80
              halign           = center
              valign           = center
            }

            label {
              monitor     =
              text        = cmd[update:1000] echo "$(date +"%H:%M")"
              color       = rgba(255, 252, 248, 1.0)
              font_size   = 72
              font_family = JetBrains Mono
              position    = 0, 100
              halign      = center
              valign      = center
            }
          '';
        };
      };
    };
}

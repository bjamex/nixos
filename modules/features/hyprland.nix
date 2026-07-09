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
          hyprpaper
          grimblast
          wf-recorder # simple Wayland screen recorder (see screenRecordToggle bind)
          gpu-screen-recorder # GPU-encoded capture + replay buffer (see gpuReplay* )
          slurp # region picker for wf-recorder / grimblast
          wl-clipboard # grimblast copy* needs wl-copy (was provided by the removed neovim module)
          inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
        ];

        hjem.users.swin.files = {
          ".config/hypr/hyprland.lua".text = ''
            -- Monitor (host-specific; see myHyprland.monitorLua)
            ${config.myHyprland.monitorLua}

            -- Startup
            hl.on("hyprland.start", function()
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
                col = {
                  active_border   = "rgba(7fc8ffff)",
                  inactive_border = "rgba(45475Aff)",
                },
                layout = "dwindle",
              },
              decoration = {
                rounding         = 12,
                active_opacity   = 0.95,
                inactive_opacity = 0.95,
                fullscreen_opacity = 1.0,
                blur = {
                  enabled  = true,
                  passes   = 2,
                  noise    = 0.02,
                  vibrancy = 0.1696,
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
            })

            -- PoE overlay tools
            hl.window_rule({ match = { title = "Exiled Exchange 2" },   tag = "+overlay" })
            hl.window_rule({ match = { class = "awakened-poe-trade" },  tag = "+overlay" })
            -- Scalpel (verify class/title with `hyprctl clients`; adjust if it differs)
            hl.window_rule({ match = { class = "Scalpel" },             tag = "+overlay" })
            hl.window_rule({ match = { title = "Scalpel" },             tag = "+overlay" })
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
            hl.bind(mod .. " + Return",       hl.dsp.exec_cmd("kitty"))
            hl.bind(mod .. " + N",            hl.dsp.exec_cmd("kitty ec"))
            hl.bind(mod .. " + W",            hl.dsp.window.close())
            hl.bind(mod .. " + Space",        hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
            hl.bind(mod .. " + SHIFT + F",    hl.dsp.exec_cmd("nautilus"))
            hl.bind(mod .. " + B",            hl.dsp.exec_cmd("helium"))
            hl.bind(mod .. " + F",            hl.dsp.exec_cmd("kitty yazi"))
            hl.bind(mod .. " + E",            hl.dsp.exec_cmd("${thunderbirdFocusOrOpen}"))
            hl.bind(mod .. " + D",            hl.dsp.exec_cmd("flatpak run com.discordapp.Discord"))
            hl.bind(mod .. " + A",            hl.dsp.exec_cmd("helium --app=https://gemini.google.com"))
            hl.bind(mod .. " + semicolon",    hl.dsp.exec_cmd("noctalia msg panel-toggle wallpaper"))
            hl.bind(mod .. " + SHIFT + V",    hl.dsp.exec_cmd("vpn-toggle"))
            hl.bind(mod .. " + SHIFT + F12",  hl.dsp.exit())
            hl.bind("Print",                  hl.dsp.exec_cmd("grimblast copysave area ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"))
            hl.bind(mod .. " + SHIFT + R",    hl.dsp.exec_cmd("${screenRecordToggle}"))
            hl.bind(mod .. " + SHIFT + S",    hl.dsp.exec_cmd("${gpuReplaySave}"))
            hl.bind(mod .. " + SHIFT + N",    hl.dsp.exec_cmd("emacs"))

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
              color   = rgba(16, 16, 16, 1.0)
              blur_passes = 2
              blur_size   = 7
            }

            input-field {
              monitor          =
              size             = 300, 50
              outline_thickness = 2
              outer_color      = rgb(7fc8ff)
              inner_color      = rgb(262626)
              font_color       = rgb(f2f4f8)
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
              color       = rgba(242, 244, 248, 1.0)
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

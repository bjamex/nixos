{ self, inputs, ... }:
{
  flake.nixosModules.niriBase =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      programs.niri.enable = true;

      environment.systemPackages = [
        pkgs.brightnessctl
        pkgs.playerctl
      ];

      xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
            user = "greeter";
          };
          initial_session = {
            command = "niri-session";
            user = "swin";
          };
        };
      };
    };

  perSystem =
    {
      pkgs,
      lib,
      self',
      ...
    }:
    let
      thunderbirdFocusOrOpen = pkgs.writeShellScript "thunderbird-focus-or-open" ''
        id=$(${lib.getExe pkgs.niri} msg --json windows 2>/dev/null | \
          ${lib.getExe pkgs.jq} -r '[.[] | select(.app_id == "thunderbird")] | .[0].id // empty')
        if [ -n "$id" ]; then
          ${lib.getExe pkgs.niri} msg action focus-window --id "$id"
        else
          thunderbird
        fi
      '';

      micMuteToggle = pkgs.writeShellScript "mic-mute-toggle" ''
        ${lib.getExe pkgs.pamixer} --default-source -t
        if [ "$(${lib.getExe pkgs.pamixer} --default-source --get-mute)" = "true" ]; then
          ${lib.getExe' pkgs.pipewire "pw-play"} ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-muted.oga
        else
          ${lib.getExe' pkgs.pipewire "pw-play"} ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga
        fi
        ${lib.getExe self'.packages.myNoctalia} ipc call cb refresh mic-status
      '';

      # Shared niri settings (keybinds, layout, input, etc.)
      niriCommonSettings = {
        spawn-at-startup = [
          (lib.getExe self'.packages.myNoctalia)
          "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
          "insync"
        ];

        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

        environment.ELECTRON_OZONE_PLATFORM_HINT = "auto";

        hotkey-overlay.skip-at-startup = true;
        prefer-no-csd = _: { };

        blur = {
          passes = 2;
          noise = 0.02;
        };

        input.keyboard.xkb.layout = "us,ua";
        input.touchpad.tap = _: { };
        input.touchpad.natural-scroll = _: { };
        input.touchpad.accel-speed = 0.2;
        input.mouse.accel-profile = "flat";
        input.focus-follows-mouse = { };
        input.warp-mouse-to-focus = { };
        layout.gaps = 7;
        layout.focus-ring = {
          width = 2;
          active-color = "#7fc8ff";
          inactive-color = "#45475A";
        };

        window-rules = [
          {
            geometry-corner-radius = 12;
            clip-to-geometry = true;
            background-effect = {
              blur = true;
            };
            opacity = 0.90;
            draw-border-with-background = false;
          }
          {
            matches = [
              { app-id = "thunderbird"; }
              { app-id = "helium"; }
            ];
            opacity = 1.0;
          }
          {
            matches = [ { app-id = "screensaver"; } ];
            open-fullscreen = true;
          }
          {
            matches = [ { app-id = "org.gnome.Calculator"; } ];
            open-floating = true;
          }
          {
            matches = [ { app-id = "exiled-exchange"; } ];
            open-floating = true;
            open-focused = false;
            opacity = 1.0;
            geometry-corner-radius = 0;
            clip-to-geometry = false;
          }
          {
            matches = [
              {
                app-id = "steam";
                title = "^notificationtoasts_\\d+_desktop$";
              }
            ];
            default-floating-position = _: {
              props = {
                x = 0;
                y = 0;
                relative-to = "bottom-right";
              };
            };
            open-focused = false;
          }
        ];

        binds = {
          "Mod+Return".spawn-sh = "kitty";
          "Mod+N".spawn-sh = "kitty nvim";
          "Mod+W".close-window = _: { };
          "Mod+Space".spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call launcher toggle";
          "Mod+Left".focus-column-left = _: { };
          "Mod+Right".focus-column-right = _: { };
          "Mod+Up".focus-window-up = _: { };
          "Mod+Down".focus-window-down = _: { };
          "Mod+Shift+Left".move-column-left = _: { };
          "Mod+Shift+Right".move-column-right = _: { };
          "Mod+Shift+Up".move-window-up = _: { };
          "Mod+Shift+Down".move-window-down = _: { };
          "Mod+Shift+F".fullscreen-window = _: { };
          "Mod+M".maximize-column = _: { };
          "Mod+C".center-column = _: { };
          "Mod+Comma".consume-window-into-column = _: { };
          "Mod+Period".expel-window-from-column = _: { };
          "Mod+Tab".toggle-overview = _: { };
          "Mod+1".focus-workspace = 1;
          "Mod+2".focus-workspace = 2;
          "Mod+3".focus-workspace = 3;
          "Mod+4".focus-workspace = 4;
          "Mod+5".focus-workspace = 5;
          "Mod+6".focus-workspace = 6;
          "Mod+7".focus-workspace = 7;
          "Mod+8".focus-workspace = 8;
          "Mod+9".focus-workspace = 9;
          "Mod+Shift+1".move-column-to-workspace = 1;
          "Mod+Shift+2".move-column-to-workspace = 2;
          "Mod+Shift+3".move-column-to-workspace = 3;
          "Mod+Shift+4".move-column-to-workspace = 4;
          "Mod+Shift+5".move-column-to-workspace = 5;
          "Mod+Shift+6".move-column-to-workspace = 6;
          "Mod+Shift+7".move-column-to-workspace = 7;
          "Mod+Shift+8".move-column-to-workspace = 8;
          "Mod+Shift+9".move-column-to-workspace = 9;
          "Print".screenshot = _: { };
          "Mod+Shift+slash".show-hotkey-overlay = _: { };
          "Mod+V".toggle-window-floating = _: { };
          "Mod+O".toggle-window-rule-opacity = _: { };
          "Mod+B".spawn-sh = "helium";
          "Mod+Shift+V".spawn-sh = "vpn-toggle";
          "Mod+semicolon".spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call wallpaper toggle";
          "Mod+F".spawn-sh = "nautilus";
          "Mod+E".spawn-sh = "${thunderbirdFocusOrOpen}";
          "Mod+D".spawn-sh = "flatpak run com.discordapp.Discord";
          "Mod+A".spawn-sh = "helium --app=https://gemini.google.com";
          "KP_Subtract".spawn-sh = "${micMuteToggle}";
          "Mod+WheelScrollDown".focus-workspace-down = _: { };
          "Mod+WheelScrollUp".focus-workspace-up = _: { };

          "XF86AudioMute".spawn-sh = "${lib.getExe pkgs.pamixer} -t";
          "XF86AudioLowerVolume".spawn-sh = "${lib.getExe pkgs.pamixer} -d 5";
          "XF86AudioRaiseVolume".spawn-sh = "${lib.getExe pkgs.pamixer} -i 5";
          "XF86AudioMicMute".spawn-sh = "${lib.getExe pkgs.pamixer} --default-source -t";
          "XF86MonBrightnessDown".spawn-sh = "${lib.getExe pkgs.brightnessctl} set 5%-";
          "XF86MonBrightnessUp".spawn-sh = "${lib.getExe pkgs.brightnessctl} set 5%+";
          "XF86AudioPlay".spawn-sh = "${lib.getExe pkgs.playerctl} play-pause";
          "XF86AudioNext".spawn-sh = "${lib.getExe pkgs.playerctl} next";
          "XF86AudioPrev".spawn-sh = "${lib.getExe pkgs.playerctl} previous";
          "XF86KbdBrightnessDown".spawn-sh = "${lib.getExe pkgs.brightnessctl} -d '*kbd_backlight*' set 10%-";
          "XF86KbdBrightnessUp".spawn-sh = "${lib.getExe pkgs.brightnessctl} -d '*kbd_backlight*' set 10%+";
          "XF86RFKill".spawn-sh = "rfkill toggle all";
          "XF86Bluetooth".spawn-sh = "rfkill toggle bluetooth";
        };
      };
    in
    {
      legacyPackages.niriCommonSettings = niriCommonSettings;
    };
}

{ self, inputs, ... }: {
  flake.nixosModules.hyprland =
    { pkgs, lib, ... }:
    let
      myNoctalia = self.packages.${pkgs.stdenv.hostPlatform.system}.myNoctalia;
      micMuteToggle = pkgs.writeShellScript "mic-mute-toggle" ''
        ${lib.getExe pkgs.pamixer} --default-source -t
        if [ "$(${lib.getExe pkgs.pamixer} --default-source --get-mute)" = "true" ]; then
          ${lib.getExe' pkgs.pipewire "pw-play"} ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-muted.oga
        else
          ${lib.getExe' pkgs.pipewire "pw-play"} ${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/audio-volume-change.oga
        fi
        ${lib.getExe myNoctalia} ipc call cb refresh mic-status
      '';
    in
    {
      programs.hyprland.enable = true;
      programs.hyprland.xwayland.enable = true;

      environment.systemPackages = with pkgs; [
        grim
        slurp
        wl-clipboard
        brightnessctl
        playerctl
        pamixer
        sound-theme-freedesktop
      ];

      hjem.users.swin.files.".config/hypr/hyprland.lua".text = ''
        local mod = "SUPER"

        hl.monitor({
          output   = "DP-2",
          mode     = "2560x1440@143.97",
          position = "auto",
          scale    = 1,
        })
        hl.monitor({
          output   = "",
          mode     = "highrr",
          position = "auto",
          scale    = "auto",
        })

        hl.on("hyprland.start", function()
          hl.exec_cmd("${lib.getExe myNoctalia}")
          hl.exec_cmd("${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1")
        end)

        hl.env("LIBVA_DRIVER_NAME", "radeonsi")
        hl.env("__GLX_VENDOR_LIBRARY_NAME", "mesa")
        hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

        hl.config({
          animations = {
            enabled = false,
          },
        })

        hl.config({
          general = {
            gaps_in     = 3,
            gaps_out    = 6,
            border_size = 2,
            col = {
              active_border   = "rgba(7fc8ffee)",
              inactive_border = "rgba(45475aee)",
            },
            layout = "dwindle",
          },
          decoration = {
            rounding = 12,
            blur = {
              enabled = true,
              passes  = 2,
              noise   = 0.02,
            },
          },
          input = {
            kb_layout    = "us,ua",
            follow_mouse = 1,
            accel_profile = "flat",
            mouse_refocus = false,
          },
          dwindle = {
            preserve_split = true,
          },
        })

        -- PoE2: fullscreen on workspace 5, prevent idle sleep
        hl.window_rule({
          name  = "poe2-game",
          match = { class = "steam_app_2694490" },
          workspace    = "5",
          fullscreen   = true,
          idle_inhibit = "always",
        })

        -- APT / overlay tools: float, allow focus, no decoration
        hl.window_rule({
          name  = "apt-overlay",
          match = { title = "Awakened PoE Trade" },
          float       = true,
          no_blur     = true,
          no_shadow   = true,
          border_size = 0,
          rounding    = 0,
        })
        hl.window_rule({
          name  = "exiled-exchange-overlay",
          match = { title = "Exiled Exchange 2" },
          float       = true,
          no_blur     = true,
          no_shadow   = true,
          border_size = 0,
          rounding    = 0,
        })

        -- Basic binds
        hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))
        hl.bind(mod .. " + Space",  hl.dsp.exec_cmd("${lib.getExe myNoctalia} ipc call launcher toggle"))
        hl.bind(mod .. " + N",      hl.dsp.exec_cmd("kitty nvim"))
        hl.bind(mod .. " + W",      hl.dsp.window.close())
        hl.bind(mod .. " + B",      hl.dsp.exec_cmd("helium"))
        hl.bind(mod .. " + D",      hl.dsp.exec_cmd("flatpak run com.discordapp.Discord"))
        hl.bind(mod .. " + F",      hl.dsp.exec_cmd("kitty yazi"))
        hl.bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd("nautilus"))
        hl.bind(mod .. " + V",      hl.dsp.window.float({ action = "toggle" }))
        hl.bind(mod .. " + C",      hl.dsp.window.center())
        hl.bind(mod .. " + SHIFT + M", hl.dsp.window.fullscreen())
        hl.bind(mod .. " + M",         hl.dsp.exec_cmd("hyprctl dispatch fullscreen 1"))

        -- Focus
        hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
        hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
        hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
        hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

        -- Move windows
        hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
        hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
        hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
        hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

        -- Workspaces
        for i = 1, 9 do
          hl.bind(mod .. " + " .. i,             hl.dsp.focus({ workspace = i }))
          hl.bind(mod .. " + SHIFT + " .. i,     hl.dsp.window.move({ workspace = i }))
        end

        -- Mouse
        hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
        hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

        -- PoE price check
        hl.bind("CTRL + ALT + D", hl.dsp.exec_cmd("pathoftrading"), { locked = true })

        -- Screenshot
        hl.bind("Print", hl.dsp.exec_cmd(
          "${lib.getExe pkgs.grim} -g \"$(${lib.getExe pkgs.slurp})\" - | ${pkgs.wl-clipboard}/bin/wl-copy"
        ))

        -- Media / brightness keys
        hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("${lib.getExe pkgs.pamixer} -t"),                                { locked = true, repeating = true })
        hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("${lib.getExe pkgs.pamixer} -d 5"),                              { locked = true, repeating = true })
        hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("${lib.getExe pkgs.pamixer} -i 5"),                              { locked = true, repeating = true })
        hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("${lib.getExe pkgs.pamixer} --default-source -t"),               { locked = true })
        hl.bind("KP_Subtract",           hl.dsp.exec_cmd("${micMuteToggle}"),                                              { locked = true })
        hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd("${lib.getExe pkgs.playerctl} play-pause"),                      { locked = true })
        hl.bind("XF86AudioNext",         hl.dsp.exec_cmd("${lib.getExe pkgs.playerctl} next"),                            { locked = true })
        hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd("${lib.getExe pkgs.playerctl} previous"),                        { locked = true })
        hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("${lib.getExe pkgs.brightnessctl} set 5%+"),                     { locked = true, repeating = true })
        hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${lib.getExe pkgs.brightnessctl} set 5%-"),                     { locked = true, repeating = true })
        hl.bind("XF86KbdBrightnessUp",   hl.dsp.exec_cmd("${lib.getExe pkgs.brightnessctl} -d '*kbd_backlight*' set 10%+"), { locked = true, repeating = true })
        hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("${lib.getExe pkgs.brightnessctl} -d '*kbd_backlight*' set 10%-"), { locked = true, repeating = true })
      '';
    };
}

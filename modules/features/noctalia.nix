# Noctalia v5 — native C++ Wayland shell (rewrite of the v4 Quickshell shell).
# Installed and configured through the upstream hjem module, registered in
# modules/users/swin.nix via `hjem.extraModules`. Hand-written config lands in
# ~/.config/noctalia/config.toml; GUI tweaks layer on top in
# ~/.local/state/noctalia/settings.toml, so this declarative config and the GUI
# no longer fight (unlike the v4 read-only-store setup).
{ inputs, ... }:
{
  flake.nixosModules.noctalia =
    { pkgs, ... }:
    {
      # Prebuilt binaries — avoid compiling the C++23 shell from source.
      nix.settings.extra-substituters = [ "https://noctalia.cachix.org" ];
      nix.settings.extra-trusted-public-keys = [
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];

      hjem.users.swin.programs.noctalia = {
        enable = true;
        package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;

        # Doomed (doom-one lineage), ported verbatim from the upstream scheme
        # file so the palette lives in this repo. It deliberately is NOT selected
        # via `builtin_palette`: the scheme set lives in the imperative,
        # untracked ~/.config/noctalia/colorschemes/ dir, which does not exist on
        # a fresh install (or on void), so a builtin reference would silently
        # break there. Selected below via source = "custom" + custom_palette.
        #
        # This is the single source of truth for the desktop's colours — the
        # templates block below regenerates kitty/btop/GTK/starship/Qt from it.
        # The places that CANNOT be templated (SDDM in login.nix, Hyprland
        # borders + hyprlock in hyprland.nix, Neovim in nvim/plugins/theme.lua)
        # carry hand-copied values from this palette; grep 51afef to find them.
        customPalettes.doomed = {
          dark = {
            mPrimary = "#51afef";
            mOnPrimary = "#1c1e1e";
            mSecondary = "#f2c481";
            mOnSecondary = "#1c1e1e";
            mTertiary = "#98be65";
            mOnTertiary = "#1c1e1e";
            mError = "#ff6b5a";
            mOnError = "#1c1e1e";
            mSurface = "#1c1e1e";
            mOnSurface = "#fffcf8";
            mSurfaceVariant = "#282c34";
            mOnSurfaceVariant = "#bbc2cf";
            mOutline = "#3f444a";
            mShadow = "#111212";
            mHover = "#2d3139";
            mOnHover = "#fffcf8";
            terminal = {
              background = "#1c1e1e";
              foreground = "#fffcf8";
              cursor = "#bbc2cf";
              cursorText = "#1c1e1e";
              selectionBg = "#fffcf8";
              selectionFg = "#2d3138";
              normal = {
                black = "#1c1e1e";
                red = "#ff6b5a";
                green = "#98be65";
                yellow = "#f2c481";
                blue = "#51afef";
                magenta = "#dc8ef3";
                cyan = "#46d9ff";
                white = "#bbc2cf";
              };
              bright = {
                black = "#2e323a";
                red = "#ff7665";
                green = "#a9cf76";
                yellow = "#f2c481";
                blue = "#47a5e5";
                magenta = "#c678dd";
                cyan = "#4db5bd";
                white = "#f0f6fc";
              };
            };
          };
        };

        settings = {
          shell = {
            font_family = "Adwaita Sans";
            # Hyprland already spawns polkit-gnome; don't double up.
            polkit_agent = false;
          };

          theme = {
            mode = "dark";
            source = "custom";
            custom_palette = "doomed";
            templates = {
              enable_builtin_templates = true;
              # Every app whose theme Noctalia can generate. Each template writes
              # a themes/noctalia.* file AND runs a post-hook that rewrites the
              # app's own config to point at it — which is why those configs are
              # delivered with hjem `type = "copy"` (writable) instead of
              # read-only store symlinks. A read-only symlink is exactly what
              # silently stranded btop on the old palette.
              builtin_ids = [
                "kitty"
                "btop"
                "gtk3"
                "gtk4"
                "starship"
                "qt"
              ];
            };
          };

          # Stills. (An mpvpaper video wallpaper was tried and dropped: it hung.)
          wallpaper = {
            enabled = true;
            directory = "/home/swin/Pictures/Wallpapers";
            fill_mode = "crop";
          };

          location = {
            address = "Brisbane, Australia";
          };

          weather = {
            enabled = true;
            unit = "celsius";
          };

          notification.enable_daemon = true;
          osd.position = "top_right";

          # Keep the old notification chime: see noctalia-classic below.
          audio.sound_theme = "noctalia-classic";

          dock = {
            enabled = true;
            position = "bottom";
            auto_hide = true;
            # reserve_space defaults to true and keeps the bottom exclusive zone
            # claimed even while auto-hidden, leaving a blank strip under windows.
            reserve_space = false;
            magnification = true;
            pinned = [ ];
          };

          # --- Bar (ported from the v4 layout) ---
          # left:  Launcher, Clock, MediaMini          (tamagotchi: no v5 widget)
          # center: Workspaces
          # right: mic/vpn buttons, Tray, Notifications, Battery, Bluetooth,
          #        Volume, ControlCenter               (tailscale + github-feed:
          #                                              no v5 builtin; plugins only)
          bar.main = {
            position = "top";
            background_opacity = 0.93;
            radius = 12;
            # v5.0 renamed the bar margins: margin_h -> margin_ends (gap at the
            # two ends), margin_v -> margin_edge (gap from the screen edge).
            margin_ends = 4;
            margin_edge = 4;
            capsule = true;

            start = [
              "launcher"
              "clock"
              "media"
            ];
            center = [ "workspaces" ];
            end = [
              "mic_button"
              "vpn_button"
              "tailscale_button"
              "tray"
              "notifications"
              "battery"
              "bluetooth"
              "volume"
              "control-center"
            ];
          };

          # Bar buttons. v5 custom_button is static (glyph + click commands, no
          # live polling text), so these lose the v4 MUTED/LIVE and VPN up/down
          # status text — they're plain toggles now. v5.0 replaced the single
          # `command` key with per-gesture `actions` (left/middle/right/back/
          # forward/scroll-up/scroll-down/…); a shell command needs an `exec `
          # prefix.
          widget = {
            mic_button = {
              type = "custom_button";
              glyph = "microphone";
              tooltip = "Toggle microphone mute";
              # wpctl toggles only the mute flag; pamixer's PulseAudio-compat path
              # would clobber the volume (mute-zeroes, unmute restores to ~50%).
              actions.left = "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
            };

            vpn_button = {
              type = "custom_button";
              glyph = "shield-lock";
              tooltip = "Toggle AirVPN";
              actions.left = "exec vpn-toggle";
            };

            # Replaces the broken upstream tailscale plugin, whose bar widget ran
            # `tailscale up/down` without root and so silently no-op'd. ts-toggle
            # (tailscale.nix) reads the daemon BackendState and flips it via
            # sudo NOPASSWD.
            tailscale_button = {
              type = "custom_button";
              glyph = "cloud-network";
              tooltip = "Toggle Tailscale";
              actions.left = "exec ts-toggle";
            };

            clock = {
              format = "{:%I:%M %p}";
              tooltip_format = "{:%A, %B %d, %Y}";
            };
          };

          # Control center quick-toggles (v4: Network/Bluetooth/Wallpaper/... ).
          control_center.shortcuts = [
            { type = "wifi"; }
            { type = "bluetooth"; }
            { type = "wallpaper"; }
            { type = "nightlight"; }
            { type = "notification"; }
            { type = "session"; }
          ];
        };
      };

      # --- Sound theme ---
      # Noctalia 2026-09-24 switched the notification chime from freedesktop's
      # `message` to `message-new-instant`. This theme inherits freedesktop for
      # every other event and maps message-new-instant back to message.oga.
      hjem.users.swin.files = {
        ".local/share/sounds/noctalia-classic/index.theme".text = ''
          [Sound Theme]
          Name=Noctalia classic
          Comment=freedesktop, with the original notification chime
          Inherits=freedesktop
          Directories=stereo

          [stereo]
          OutputProfile=stereo
        '';
        ".local/share/sounds/noctalia-classic/stereo/message-new-instant.oga".source =
          "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/message.oga";
      };
    };
}

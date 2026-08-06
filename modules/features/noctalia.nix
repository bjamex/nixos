{ self, inputs, ... }:
{
  # Noctalia v5 — native C++ Wayland shell (rewrite of the v4 Quickshell shell).
  # Installed and configured through the upstream hjem module, registered in
  # modules/users/swin.nix via `hjem.extraModules`. Hand-written config lands in
  # ~/.config/noctalia/config.toml; GUI tweaks layer on top in
  # ~/.local/state/noctalia/settings.toml, so this declarative config and the GUI
  # no longer fight (unlike the v4 read-only-store setup).
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

        # Oxocarbon, ported verbatim from the v4 colors.json so the whole desktop
        # (gtk, btop, kitty) stays on the same palette. Selected below via
        # theme.source = "custom" + theme.custom_palette = "oxocarbon".
        customPalettes.oxocarbon = {
          dark = {
            mPrimary = "#33b1ff";
            mOnPrimary = "#161616";
            mSecondary = "#42be65";
            mOnSecondary = "#161616";
            mTertiary = "#be95ff";
            mOnTertiary = "#161616";
            mError = "#ee5396";
            mOnError = "#161616";
            mSurface = "#161616";
            mOnSurface = "#f2f4f8";
            mSurfaceVariant = "#262626";
            mOnSurfaceVariant = "#dde1e6";
            mOutline = "#525252";
            mShadow = "#000000";
            mHover = "#78a9ff";
            mOnHover = "#161616";
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
            custom_palette = "oxocarbon";
            templates = {
              enable_builtin_templates = true;
              # kitty + btop ship as builtin templates (each with its own
              # post-hook that reloads the app) — this replaces the v4 template
              # setup AND the systemd kitty-reload watcher. NOTE: yazi has no
              # builtin v5 template; it needs a user template (follow-up).
              builtin_ids = [
                "kitty"
                "btop"
              ];
            };
          };

          # Disabled in favour of the mpvpaper video wallpaper (videoWallpaper.nix).
          # Both draw layer-shell surfaces on layer 0 and the one that maps last
          # ends up on top, so leaving this on makes the background a login race.
          # Re-enable (and drop myVideoWallpaper.enable) to go back to stills;
          # the SUPER+semicolon wallpaper panel bind is inert while it is off.
          wallpaper = {
            enabled = false;
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

          # ── Bar — ported from the v4 layout ────────────────────────────────
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

          # v5 custom_button is static (glyph + click commands, no live polling
          # text), so these lose the v4 MUTED/LIVE and VPN up/down status text —
          # they're now plain toggle buttons.
          # v5.0 replaced the single `command` key with per-gesture `actions`
          # (left/middle/right/back/forward/scroll-up/scroll-down/…); a shell
          # command has to be prefixed with `exec `.
          widget.mic_button = {
            type = "custom_button";
            glyph = "microphone";
            tooltip = "Toggle microphone mute";
            # wpctl toggles only the mute flag; pamixer's PulseAudio-compat path
            # would clobber the volume (mute-zeroes, unmute restores to ~50%).
            actions.left = "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
          };
          widget.vpn_button = {
            type = "custom_button";
            glyph = "shield-lock";
            tooltip = "Toggle AirVPN";
            actions.left = "exec vpn-toggle";
          };
          # Plain toggle (no live status) — replaces the broken upstream
          # tailscale plugin whose bar widget ran `tailscale up/down` without
          # root, so it silently no-op'd. ts-toggle (tailscale.nix) reads the
          # daemon BackendState and flips it via sudo NOPASSWD.
          widget.tailscale_button = {
            type = "custom_button";
            glyph = "cloud-network";
            tooltip = "Toggle Tailscale";
            actions.left = "exec ts-toggle";
          };

          widget.clock = {
            format = "{:%I:%M %p}";
            tooltip_format = "{:%A, %B %d, %Y}";
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
    };
}

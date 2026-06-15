{ self, ... }:
{
  # Compositor-neutral login/session foundation: greeter, keyring, portal and
  # Wayland env. Previously these lived inside niri-base.nix; extracted so the
  # single remaining compositor (Hyprland) keeps a working login on both hosts.
  flake.nixosModules.login =
    { config, pkgs, lib, ... }:
    {
      environment.systemPackages = [
        pkgs.brightnessctl
        pkgs.playerctl
      ];

      services.gnome.gnome-keyring.enable = true;
      security.pam.services.greetd.enableGnomeKeyring = true;

      xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

      services.greetd = {
        enable = true;
        # Stop systemd boot/service-startup messages from scribbling over the
        # tuigreet TUI on first boot (adjusts the greetd unit's console wiring).
        useTextGreeter = true;
        settings = {
          default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
            user = "greeter";
          };
        };
      };

      # Wayland-native hints for Electron/Chromium + Qt apps. NIXOS_OZONE_WL and
      # QT_QPA_PLATFORM previously lived in styx's host config; ELECTRON_OZONE_*
      # came from Niri's internal env. Centralised here so void gets them too.
      environment.sessionVariables = {
        NIXOS_OZONE_WL = "1";
        QT_QPA_PLATFORM = "wayland";
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
      };
    };
}

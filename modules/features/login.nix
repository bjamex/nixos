{ self, ... }:
{
  # Compositor-neutral login/session foundation: greeter, keyring, portal and
  # Wayland env. Previously these lived inside niri-base.nix; extracted so the
  # single remaining compositor (Hyprland) keeps a working login on both hosts.
  flake.nixosModules.login =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # where-is-my-sddm-theme: ultra-minimal greeter, tinted to Oxocarbon.
      # qt6 variant is the default, matching SDDM's qt6 greeter.
      sddmTheme = pkgs.where-is-my-sddm-theme.override {
        themeConfig.General = {
          backgroundFill = "#161616"; # Oxocarbon base00
          basicTextColor = "#f2f4f8"; # near-white (base05)
          passwordCursorColor = "#3ddbd9"; # Oxocarbon teal accent
        };
      };
    in
    {
      environment.systemPackages = [
        pkgs.brightnessctl
        pkgs.playerctl
        # Theme lives on the ThemeDir path (/run/current-system/sw/share/sddm/themes),
        # so it has to be a system package, not just sddm.extraPackages.
        sddmTheme
      ];

      services.gnome.gnome-keyring.enable = true;
      security.pam.services.sddm.enableGnomeKeyring = true;

      xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

      # SDDM greeter runs under X11 (not the experimental Wayland greeter, whose
      # embedded weston crashes on this RX 9070 XT / Mesa via a DRM-format
      # assertion). The X server here is *only* for the login screen — the actual
      # Hyprland session it launches is still Wayland.
      services.xserver.enable = true;
      # Hyprland ships both a plain and a uwsm-managed session; the uwsm one fails
      # its systemd bindpid handshake under SDDM, so default to the plain session
      # (Exec=start-hyprland) — the same one greetd/tuigreet launched fine.
      services.displayManager.defaultSession = "hyprland";
      services.displayManager.sddm = {
        enable = true;
        theme = "where_is_my_sddm_theme";
        # Qt/QML plugins the theme needs at greeter runtime, from its propagated inputs.
        extraPackages = sddmTheme.propagatedBuildInputs;
      };

      # Wayland-native hints for Electron/Chromium + Qt apps. NIXOS_OZONE_WL and
      # QT_QPA_PLATFORM previously lived in styx's host config; ELECTRON_OZONE_*
      # came from Niri's internal env. Centralised here so void gets them too.
      environment.sessionVariables = {
        NIXOS_OZONE_WL = "1";
        # Fallback list: Qt apps prefer wayland (Hyprland), but fall back to xcb
        # when there's no wl_display — e.g. SDDM's X11 greeter, which otherwise
        # aborts trying to load the wayland platform plugin.
        QT_QPA_PLATFORM = "wayland;xcb";
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
      };
    };
}

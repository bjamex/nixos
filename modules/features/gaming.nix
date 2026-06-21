{ self, inputs, ... }: {
  flake.nixosModules.gaming = { pkgs, lib, ... }:
  let
    rusty-path-of-building = pkgs.rusty-path-of-building.overrideAttrs (_: {
      version = "0.2.18";
      src = pkgs.fetchzip {
        url = "https://github.com/meehl/rusty-path-of-building/archive/refs/tags/v0.2.18.tar.gz";
        hash = "sha256-9YHXTUtTJO3GPf+NqASEkxf+a94doBGTjLyYruuxRg4=";
      };
      cargoDeps = pkgs.rustPlatform.importCargoLock {
        lockFile = ./rusty-path-of-building-Cargo.lock;
      };
    });
  in
  {
    imports = [ inputs.nix-gaming.nixosModules.pipewireLowLatency ];

    hardware.graphics.enable = lib.mkDefault true;
    hardware.graphics.enable32Bit = lib.mkDefault true;
    hardware.graphics.extraPackages = with pkgs; [ rocmPackages.clr ];

    hardware.xpadneo.enable = true;

    programs = {
      gamemode.enable = true;
      gamescope.enable = true;
      steam = {
        enable = true;
        protontricks.enable = true;
      };
    };

    environment.systemPackages = (with pkgs; [
      pkgs.stable.lutris
      steam-run
      dxvk
      mangohud
      r2modman
      heroic
      er-patcher
      bottles
      steamtinkerlaunch
      prismlauncher
      mcpelauncher-client
      mcpelauncher-ui-qt
      lsfg-vk
      lsfg-vk-ui
      faugus-launcher
      xivlauncher
      shadps4
      appimage-run
    ]) ++ [ rusty-path-of-building ];

    # The Steam Linux Runtime hardcodes TZDIR=/usr/share/zoneinfo for the
    # processes it spawns (Proton, the game), which doesn't exist on NixOS — so
    # name-based TZ lookups fall back to UTC and games show the wrong time.
    # Symlink it to the real tzdata so e.g. Path of Exile reads the right zone.
    systemd.tmpfiles.rules = [ "L+ /usr/share/zoneinfo - - - - /etc/zoneinfo" ];

    services.sunshine = {
      openFirewall = true;
      enable = true;
      autoStart = true;
      capSysAdmin = true;
      applications = {
        apps = [
          {
            name = "Steam Big Picture";
            detached = [ "setsid steam -gamepadui" ];
          }
        ];
      };
    };

    nix.settings = {
      substituters = [ "https://nix-gaming.cachix.org" ];
      trusted-public-keys = [ "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" ];
    };
  };
}

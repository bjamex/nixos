{ self, inputs, ... }: {
  flake.nixosModules.gaming = { pkgs, lib, ... }:
  {
    imports = [ inputs.nix-gaming.nixosModules.pipewireLowLatency ];

    hardware.graphics.enable = lib.mkDefault true;
    hardware.graphics.enable32Bit = lib.mkDefault true;
    hardware.graphics.extraPackages = with pkgs; [ rocmPackages.clr ];

    hardware.xpadneo.enable = true;

    # Xbox controllers over Bluetooth misbehave on the Intel combo adapter:
    #  - ERTM must be disabled or the controller connects but no input device
    #    is created;
    #  - btusb autosuspend must be off or the radio suspends when the pad idles,
    #    dropping the link every ~20s (endless flashing/reconnect loop).
    boot.extraModprobeConfig = ''
      options bluetooth disable_ertm=Y
      options btusb enable_autosuspend=N
    '';

    # BlueZ settings that make the Xbox controller pair cleanly and stay
    # connected (solid light, no ~90s BLE reconnect loop). JustWorksRepairing
    # + FastConnectable are the key ones for the controller's HOGP link.
    hardware.bluetooth.settings.General = {
      Privacy = "device";
      JustWorksRepairing = "always";
      Class = "0x000100";
      FastConnectable = "true";
    };

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
    ]);

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

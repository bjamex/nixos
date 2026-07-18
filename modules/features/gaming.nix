{ self, inputs, ... }: {
  flake.nixosModules.gaming = { pkgs, lib, ... }:
  let
    # shadps4-qtlauncher is the Qt GUI frontend (it pulls in the shadps4 core as
    # its emulator backend); the plain shadps4 binary is CLI-only. Neither ships
    # a .desktop entry or icon, so generate one — using the upstream icon — that
    # launches the Qt GUI.
    shadps4Icon = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/shadps4-emu/shadPS4/main/.github/shadps4.png";
      sha256 = "15a79cphq8qca7ndvwmyzbzk1wvs01ghf766wc1jvkf576hv89mg";
    };
    shadps4Desktop = pkgs.makeDesktopItem {
      name = "shadps4";
      desktopName = "shadPS4";
      genericName = "PlayStation 4 Emulator";
      comment = "Emulate PlayStation 4 games";
      exec = "shadPS4QtLauncher";
      icon = "${shadps4Icon}";
      categories = [ "Game" "Emulator" ];
      terminal = false;
    };
  in
  {
    imports = [ inputs.nix-gaming.nixosModules.pipewireLowLatency ];

    # patool 4.0.5's check phase fails under nixpkgs 2026-07-15 — its tests can't
    # find the archiver helpers (list_xz/list_bzip2/...) on the build PATH and a
    # libmagic mime assertion mismatches — which blocks bottles. patool resolves
    # archivers at runtime via PATH, so these are test-env failures only; skip
    # the checks. Drop this overlay once nixpkgs fixes patool upstream.
    nixpkgs.overlays = [
      (final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (pyfinal: pyprev: {
            patool = pyprev.patool.overridePythonAttrs (_: {
              doCheck = false;
              doInstallCheck = false;
            });
          })
        ];
      })
    ];

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

    # The Series pad connects over BLE/HOGP but doesn't advertise usable
    # connection parameters, so BlueZ defaults let it drop every ~60-90s.
    # Pin the interval to ~8.75-11.25ms to match its 100Hz protocol. Per
    # xpadneo TROUBLESHOOTING; BlueZ may still let the pad override these.
    hardware.bluetooth.settings.LE = {
      MinConnectionInterval = 7;
      MaxConnectionInterval = 9;
      ConnectionLatency = 0;
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
      shadps4            # core emulator binary (also what BB_Launcher execs to run the game)
      shadps4-qtlauncher # Qt GUI frontend
      shadps4Desktop
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

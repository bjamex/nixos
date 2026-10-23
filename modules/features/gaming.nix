# Gaming: Steam + launchers, Sunshine streaming, and the Xbox
# controller Bluetooth fixes. Imported on both desktops via common.nix.
{ inputs, ... }:
{
  flake.nixosModules.gaming =
    { pkgs, lib, ... }:
    let
      # PoE Campaign Copilot — passive leveling overlay built from source (no
      # upstream Linux release). Point its Settings at the Proton install's
      # Client.txt, e.g. ~/.local/share/Steam/steamapps/common/Path of Exile/logs/Client.txt
      poe-campaign-copilot = pkgs.callPackage ../../pkgs/poe-campaign-copilot { };
    in
    {
      imports = [ inputs.nix-gaming.nixosModules.pipewireLowLatency ];

      # --- Overlays ---
      # patool 4.0.5's check phase fails under nixpkgs 2026-07-15 — its tests can't
      # find the archiver helpers (list_xz/list_bzip2/...) on the build PATH and a
      # libmagic mime assertion mismatches — which blocks bottles. patool resolves
      # archivers at runtime via PATH, so these are test-env failures only; skip
      # the checks. Drop this overlay once nixpkgs fixes patool upstream.
      nixpkgs.overlays = [
        (_: prev: {
          pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
            (_: pyprev: {
              patool = pyprev.patool.overridePythonAttrs (_: {
                doCheck = false;
                doInstallCheck = false;
              });
            })
          ];
        })
      ];

      # --- Graphics ---
      hardware.graphics = {
        enable = lib.mkDefault true;
        enable32Bit = lib.mkDefault true;
        # .icd registers the AMD OpenCL vendor ICD in /run/opengl-driver; without
        # it the OpenCL platform list is empty (darktable falls back to CPU).
        extraPackages = with pkgs.rocmPackages; [
          clr
          clr.icd
        ];
      };

      hardware.xpadneo.enable = true;

      # --- Controllers ---
      # Xbox controllers over Bluetooth misbehave on the Intel combo adapter:
      #  - ERTM must be disabled or the controller connects but no input device
      #    is created;
      #  - btusb autosuspend must be off or the radio suspends when the pad idles,
      #    dropping the link every ~20s (endless flashing/reconnect loop).
      boot.extraModprobeConfig = ''
        options bluetooth disable_ertm=Y
        options btusb enable_autosuspend=N
      '';

      # The btusb option above isn't enough on its own: systemd's
      # 60-autosuspend-chromiumos.hwdb tags the AX201 (8087:0026) with
      # ID_AUTOSUSPEND=1, and udev flips power/control back to "auto".
      services.udev.extraRules = ''
        ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="8087", ATTR{idProduct}=="0026", ATTR{power/control}="on"
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

      # --- Programs & packages ---
      programs = {
        gamemode.enable = true;
        gamescope.enable = true;
        steam = {
          enable = true;
          protontricks.enable = true;
        };
      };

      environment.systemPackages = with pkgs; [
        stable.lutris
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
        xivlauncher
        wowup-cf # WoW addon manager (CurseForge + Wago); point it at the Steam prefix install
        poe-campaign-copilot # PoE leveling overlay (see let-binding above)
        appimage-run
      ];

      # --- Steam runtime ---
      # The Steam Linux Runtime hardcodes TZDIR=/usr/share/zoneinfo for the
      # processes it spawns (Proton, the game), which doesn't exist on NixOS — so
      # name-based TZ lookups fall back to UTC and games show the wrong time.
      # Symlink it to the real tzdata so e.g. Path of Exile reads the right zone.
      systemd.tmpfiles.rules = [ "L+ /usr/share/zoneinfo - - - - /etc/zoneinfo" ];

      # --- LAN play ---
      # Minecraft "Open to LAN" picks a random ephemeral port by default, but the
      # Open-to-LAN screen lets you type one — always enter 33737 so a single
      # fixed rule covers it instead of the whole ephemeral range. Scoped to the
      # local subnet: LAN worlds are unauthenticated, so this must not be
      # reachable from Tailscale or anywhere else.
      networking.firewall.extraCommands = ''
        iptables -A nixos-fw -s 192.168.0.0/24 -p tcp --dport 33737 -j nixos-fw-accept
      '';

      # --- Streaming ---
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

      # --- Binary cache ---
      nix.settings = {
        substituters = [ "https://nix-gaming.cachix.org" ];
        trusted-public-keys = [ "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" ];
      };
    };
}

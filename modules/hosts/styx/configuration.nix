{ self, inputs, ... }:
{

  flake.nixosModules.styxConfiguration =
    { pkgs, lib, ... }:
    {
      imports = [
        inputs.lix-module.nixosModules.lixFromNixpkgs
        self.nixosModules.styxHardware
        self.nixosModules.common # shared styx/void desktop foundation
        self.nixosModules.login
        self.nixosModules.hyprland
        self.nixosModules.noctalia
        self.nixosModules.gaming
        self.nixosModules.bblauncher # Bloodborne launcher/mod manager for shadPS4
        self.nixosModules.rustyPob # rusty-path-of-building (PoE build planner)
        self.nixosModules.beammp # BeamNG.drive multiplayer launcher
        self.nixosModules.virtualisation # libvirt/KVM + virt-manager
        self.nixosModules.pipewire
        self.nixosModules.fileManager
        self.nixosModules.kitty
        self.nixosModules.emacs
        self.nixosModules.llm
        self.nixosModules.insync
        self.nixosModules.swinHome
        self.nixosModules.smb
        # self.nixosModules.starCitizen  # broken: dxvk cross-compilation fails on nixpkgs f83fc3c
        self.nixosModules.awakenedPoeTrade
        self.nixosModules.thunderbird
        self.nixosModules.exiledExchange
        self.nixosModules.scalpel # alternative PoE2 overlay/price checker
        self.nixosModules.comfyui
        self.nixosModules.airvpn
        self.nixosModules.tailscale
        # self.nixosModules.website
        self.nixosModules.budslink
        self.nixosModules.shell
        self.nixosModules.bambuStudio # upstream AppImage; nixpkgs' is unfree/uncached (local source build)
        self.nixosModules.davinciResolve # from nixpkgs (21.x) since the version-bump overlay was dropped 2026-07-18

        self.nixosModules.voiceServer # Wyoming faster-whisper ASR, tailnet-wide
        self.nixosModules.voiceSatellite # "Hey Jarvis" wake word -> ASR -> local commands
      ];

      # --- Boot ---
      boot.loader.timeout = 0;
      boot.kernelModules = [
        "igc"
        "snd_usb_audio"
      ];
      boot.kernelParams = [ "split_lock_detect=off" ];

      # dbus-broker uses Type=notify so systemd waits 90s for a READY signal
      # that never arrives. Cap the timeout so rebuilds fail fast instead of hanging.
      systemd.user.services.dbus-broker.serviceConfig = {
        ExecReload = "${pkgs.coreutils}/bin/true";
        TimeoutReloadSec = "5";
      };

      # --- Networking ---
      networking.hostName = "styx";

      # KDE Connect: installs kdeconnect-kde and opens TCP/UDP 1714-1764
      programs.kdeconnect.enable = true;

      # Pin voice capture to the USB microphone rather than the system default
      # source — otherwise a Bluetooth headset (e.g. the AKG N5) can hijack the
      # default and, if muted, leave voice control reading silence.
      voice.satellite.micDevice = "alsa_input.usb-Generic_USB_Audio-00.HiFi__Mic__source";

      # --- Locale ---
      # en_GB: Bambu Studio's "English" UI locale — with only en_AU in the
      # locale archive it warns "Switching language en_GB failed" on launch.
      # (Setting this option replaces the auto-derived default, so the host
      # locale + C must be listed explicitly.)
      i18n.supportedLocales = [
        "C.UTF-8/UTF-8"
        "en_AU.UTF-8/UTF-8"
        "en_GB.UTF-8/UTF-8"
        "en_US.UTF-8/UTF-8"
      ];

      # --- Hardware ---
      hardware.amdgpu.initrd.enable = true;

      # --- Printing ---
      hardware.printers.ensureDefaultPrinter = "EPSON_SC_T3100_Series";
      hardware.printers.ensurePrinters = [
        {
          name = "EPSON_SC_T3100_Series";
          location = "Local";
          deviceUri = "dnssd://EPSON%20SC-T3100%20Series._ipp._tcp.local/?uuid=cfe92100-67c4-11d4-a45f-9caed3d3a501";
          model = "everywhere";
          ppdOptions.InputSlot = "Rear";
        }
      ];

      # --- Programs ---
      programs.nix-ld.enable = true;

      # --- Services ---
      services.ratbagd.enable = true;

      # --- Users ---
      # Base user + shared groups come from common.nix; these merge on top.
      users.users.swin.extraGroups = [
        "input"
        "ratbagd"
      ];

      # --- Packages (styx-only; shared set lives in common.nix) ---
      environment.systemPackages = with pkgs; [
        # Shell utilities
        unzip

        # Mouse
        piper
        solaar

        # Terminal & System
        nvtopPackages.amd
        tickrs

        # Internet & Communication
        mcp-nixos
        teams-for-linux

        # Media & Creative
        blender
        ## bambu-studio  # from nixpkgs = local source build; see bambu-studio.nix

        # Productivity
        orca-slicer
        simple-scan
        typora

        # Containers (uses the docker backend enabled in common.nix)
        distrobox
      ];

      # Single Gigabyte M27Q desktop monitor; Hyprland base auto-detects otherwise.
      myHyprland.monitorLua = ''hl.monitor({ output = "desc:GIGA-BYTE TECHNOLOGY CO. LTD. M27Q", mode = "2560x1440@143.856", position = "0x0", scale = 1 })'';

      # Always-on desktop: don't auto-suspend or auto-lock on idle.
      myHyprland.autoSuspend = false;
      myHyprland.idleLock = false;

      # --- Storage ---
      fileSystems."/mnt/nvme0" = {
        device = "/dev/disk/by-uuid/6ab3631f-5d79-466e-a9fe-10aaddf7ce6e";
        fsType = "ext4";
      };
      fileSystems."/mnt/nvme2" = {
        device = "/dev/disk/by-uuid/eba90478-2582-4260-b65d-70cb4ffa1352";
        fsType = "ext4";
      };
      fileSystems."/mnt/nvme3" = {
        device = "/dev/disk/by-uuid/3a71adec-87f1-430e-a3e3-9f1dd30e9b50";
        fsType = "ext4";
      };

      system.stateVersion = "25.11";
    };
}

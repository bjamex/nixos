# styx — main desktop (RX 9070 XT, dual-boots Windows from its own disk).
# Everything shared with void comes from common.nix; this file holds only what
# is styx-specific.
{ self, ... }:
{
  flake.nixosModules.styxConfiguration =
    { pkgs, ... }:
    {
      imports = [
        self.nixosModules.styxHardware
        self.nixosModules.common # shared styx/void desktop foundation
        self.nixosModules.noctalia
        self.nixosModules.secureboot # inert until mySecureBoot.enable; see the module header

        # System
        self.nixosModules.virtualisation # libvirt/KVM + virt-manager
        self.nixosModules.nixLd # unpatched binaries (Playwright's Chromium et al)
        self.nixosModules.llm # ollama + open-webui
        self.nixosModules.insyncNotify # Insync 3.9.10 lost its own notifications
        self.nixosModules.airvpn

        # Games
        self.nixosModules.bblauncher # Bloodborne launcher/mod manager for shadPS4
        self.nixosModules.beammp # BeamNG.drive multiplayer launcher
        self.nixosModules.rustyPob # rusty-path-of-building (PoE build planner)
        self.nixosModules.awakenedPoeTrade # PoE1 price checker
        self.nixosModules.exiledExchange # PoE2 price checker
        self.nixosModules.scalpel # alternative PoE2 overlay/price checker
        self.nixosModules.stashsage # PoE2 ML price prediction overlay (~2.8GB store path)

        # Apps
        self.nixosModules.budslink
        self.nixosModules.jdownloader # bootstraps upstream jar into ~/.local/share/jdownloader
        self.nixosModules.packetTracer # needs the NetAcad .deb added by hand, see module
      ];

      # --- Boot ---
      boot = {
        # 5s so the menu is actually reachable now that Windows is installed on
        # the 850 EVO (S2R4NX0H809823P). Note systemd-boot will NOT list
        # Windows: it only shows entries from its own ESP, and Windows made its
        # own on sda1 rather than borrowing this one. Switch OS from the
        # firmware boot menu (F11); this timeout just stops NixOS booting
        # before you can.
        loader.timeout = 5;
        kernelModules = [
          "igc"
          "snd_usb_audio"
        ];
        kernelParams = [ "split_lock_detect=off" ];
      };

      # Secure Boot, so Ricochet is satisfied while NixOS still boots. First
      # switch installs lanzaboote unsigned (autoGenerateKeys sets
      # allowUnsigned); the keys appear on the next boot and a second rebuild
      # signs. Full ceremony in features/secureboot.nix.
      mySecureBoot.enable = true;

      # --- Networking ---
      networking.hostName = "styx";

      # --- Locale & Time ---
      # Windows writes local time to the RTC; NixOS assumes UTC. Without this
      # each OS drags the clock 10 hours (Australia/Brisbane) whenever you
      # switch, and NixOS then re-fights it via NTP. Host-only, not in
      # common.nix, because void has no Windows install to appease.
      time.hardwareClockInLocalTime = true;
      i18n.supportedLocales = [
        "C.UTF-8/UTF-8"
        "en_AU.UTF-8/UTF-8"
        "en_GB.UTF-8/UTF-8"
        "en_US.UTF-8/UTF-8"
      ];

      # --- Hardware ---
      hardware.amdgpu.initrd.enable = true;

      # --- Printing ---
      # The T3100 cannot render PDF — its IPP document-format-supported is only
      # {octet-stream, pwg-raster, urf, jpeg}. But `model = "everywhere"` makes
      # cups-filters' `driverless` generate a PPD whose sole rule is
      #   *cupsFilter2: "application/vnd.cups-pdf application/pdf 0 -"
      # i.e. hand the printer raw PDF. It accepts that as octet-stream (its
      # default format, which matches anything), fails to parse it, and reports
      # completed-successfully with job-impressions-completed = 0 — a silent
      # no-op with no error anywhere. Ship a corrected copy of that same PPD
      # with a real raster chain (PDF -> pdftoraster -> rastertopwg -> URF).
      services.printing.drivers = [
        (pkgs.runCommand "epson-sc-t3100-urf-ppd" { } ''
          mkdir -p $out/share/cups/model
          cp ${./epson-sc-t3100-urf.ppd} $out/share/cups/model/epson-sc-t3100-urf.ppd
        '')
      ];
      hardware.printers = {
        ensureDefaultPrinter = "EPSON_SC_T3100_Series";
        ensurePrinters = [
          {
            name = "EPSON_SC_T3100_Series";
            location = "Local";
            deviceUri = "dnssd://EPSON%20SC-T3100%20Series._ipp._tcp.local/?uuid=cfe92100-67c4-11d4-a45f-9caed3d3a501";
            model = "epson-sc-t3100-urf.ppd";
            ppdOptions.InputSlot = "Rear";
          }
        ];
      };

      # --- Services ---
      services.ratbagd.enable = true;

      # Enrolling custom Secure Boot keys meant clearing the factory variables,
      # which took dbx (431 revoked signatures) with it — sbctl enrolls PK, KEK
      # and db but not dbx. fwupd ships the UEFI revocation list as an ordinary
      # device update, so `fwupdmgr get-updates` can put it back. Enabling the
      # service applies nothing on its own; updates are still opt-in per run.
      services.fwupd.enable = true;

      systemd.user.services.dbus-broker.serviceConfig = {
        ExecReload = "${pkgs.coreutils}/bin/true";
        TimeoutReloadSec = "5";
      };

      # Insync's sync root. drive/ and sharedwithme/ hold nothing, so watching
      # share/ covers every folder that actually receives files.
      insyncNotify.paths = [ "/mnt/nvme3/share" ];

      # --- Users ---
      # Base user + shared groups come from common.nix; these merge on top.
      users.users.swin.extraGroups = [
        "input"
        "ratbagd"
      ];

      # --- Desktop ---
      myHyprland = {
        monitorLua = ''hl.monitor({ output = "desc:GIGA-BYTE TECHNOLOGY CO. LTD. M27Q", mode = "2560x1440@143.856", position = "0x0", scale = 1 })'';
        autoSuspend = false;
        idleLock = false;
      };

      # --- Packages (styx-only; shared set lives in common.nix) ---
      programs.firefox.enable = true;

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
        webex # unfree, so uncached — builds locally (a .deb unpack + autoPatchelf)

        # Media & Creative
        blender
        kdePackages.kdenlive
        video2x # AI upscaling/interpolation (Real-ESRGAN, RIFE…) on Vulkan — the 9070 XT is device 0

        # Productivity
        orca-slicer
        simple-scan
        typora

        # Containers (uses the docker backend enabled in common.nix)
        distrobox
      ];

      # --- Storage ---
      fileSystems = {
        "/mnt/nvme0" = {
          device = "/dev/disk/by-uuid/6ab3631f-5d79-466e-a9fe-10aaddf7ce6e";
          fsType = "ext4";
          options = [ "nofail" ];
        };
        "/mnt/nvme2" = {
          device = "/dev/disk/by-uuid/eba90478-2582-4260-b65d-70cb4ffa1352";
          fsType = "ext4";
          options = [ "nofail" ];
        };
        "/mnt/nvme3" = {
          device = "/dev/disk/by-uuid/3a71adec-87f1-430e-a3e3-9f1dd30e9b50";
          fsType = "ext4";
          options = [ "nofail" ];
        };
      };

      system.stateVersion = "25.11";
    };
}

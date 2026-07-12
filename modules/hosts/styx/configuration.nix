{ self, inputs, ... }:
{

  flake.nixosModules.styxConfiguration =
    { pkgs, lib, ... }:
    {
      imports = [
        inputs.lix-module.nixosModules.lixFromNixpkgs
        self.nixosModules.styxHardware
        self.nixosModules.login
        self.nixosModules.hyprland
        self.nixosModules.noctalia
        self.nixosModules.gaming
        self.nixosModules.rustyPob # rusty-path-of-building (PoE build planner)
        self.nixosModules.beammp # BeamNG.drive multiplayer launcher
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
        self.nixosModules.rapidraw # AppImage overlay — stays current with upstream
        self.nixosModules.matcha # matcha.email — TUI email client
        self.nixosModules.zed # Zed editor + Claude Code via ACP
        # self.nixosModules.davinciResolve  # blackmagic source download broken after nixpkgs bump 2026-06-30

        self.nixosModules.focus # Pomodoro focus timer TUI
        self.nixosModules.focusWidget # Pomodoro focus timer — Noctalia bar widget
      ];

      # --- Nix ---
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      nix.settings.auto-optimise-store = true;
      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 14d";
      };
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [
        (final: prev: {
          # pkgs.stable pinned for lutris — unstable broke it around 2025-06
          stable = import inputs.nixpkgs-pinned {
            system = final.stdenv.hostPlatform.system;
            config.allowUnfree = true;
          };
        })
      ];

      # --- Boot ---
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.loader.timeout = 0;
      boot.kernelPackages = pkgs.linuxPackages_latest;
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
      networking.networkmanager.enable = true;
      networking.firewall.enable = true;
      services.openssh.enable = false;

      # KDE Connect: installs kdeconnect-kde and opens TCP/UDP 1714-1764
      programs.kdeconnect.enable = true;

      # --- Locale & Time ---
      time.timeZone = "Australia/Brisbane";
      i18n.defaultLocale = "en_AU.UTF-8";

      # --- Hardware ---
      hardware.amdgpu.initrd.enable = true;

      # --- Bluetooth ---
      hardware.bluetooth.enable = true;
      hardware.bluetooth.powerOnBoot = true;
      services.blueman.enable = true;

      # --- Scanning ---
      hardware.sane.enable = true;

      # --- Printing ---
      services.printing.enable = true;
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };
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

      # --- Virtualisation ---
      virtualisation.docker.enable = true;

      # --- Shell ---
      # `ec` = emacsclient terminal frame on the daemon (see emacs.nix), with a
      # self-start fallback. Plain `emacs` is still the standalone instance.
      programs.bash.shellAliases.n = "ec";

      # --- Programs ---
      programs.nix-ld.enable = true;
      security.polkit.enable = true;
      programs.appimage = {
        enable = true;
        binfmt = true;
      };

      # --- Services ---
      services.flatpak.enable = true;
      services.ratbagd.enable = true;
      # --- Users ---
      users.users.swin = {
        isNormalUser = true;
        description = "Brett James";
        extraGroups = [
          "networkmanager"
          "wheel"
          "render"
          "video"
          "docker"
          "scanner"
          "lp"
          "disk"
          "dialout"
          "input"
          "ratbagd"
        ];
      };

      # --- Packages ---
      environment.systemPackages = with pkgs; [
        # Shell utilities

        unzip
        (writeShellScriptBin "nwhich" "readlink -f $(which $1)")
        (writeShellScriptBin "cnwhich" "cat $(readlink -f $(which $1))")
        (writeShellScriptBin "md" "mkdir -p \"$1\" && cd \"$1\"")

        # Development
        git
        gh
        vscode-fhs
        claude-code
        nh

        # Mouse
        piper
        solaar

        # Terminal & System
        btop
        ncdu
        baobab
        fzf
        lazygit
        nvtopPackages.amd
        weathr
        tickrs

        # Internet & Communication
        inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.helium
        mcp-nixos
        qbittorrent
        nordpass
        teams-for-linux
        localsend
        # Media & Creative
        komikku
        rapidraw
        obs-studio
        darktable
        jellyfin-tui
        ani-cli
        loupe
        vlc
        inkscape
        pinta
        xournalpp
        blender
        ## bambu-studio
        # Productivity
        impression
        libreoffice
        gnome-calculator
        pdfarranger
        freecad
        orca-slicer
        simple-scan
        typora
        obsidian
        affine

        # Networking & Monitoring
        nethogs
        linssid
        moonlight-qt
        pamixer
        cifs-utils
        baobab

        # Containers (uses the docker backend already enabled above)
        distrobox
      ];

      # --- Browser ---
      xdg.mime.defaultApplications = {
        "text/html" = "helium.desktop";
        "x-scheme-handler/http" = "helium.desktop";
        "x-scheme-handler/https" = "helium.desktop";
        "x-scheme-handler/about" = "helium.desktop";
        "x-scheme-handler/unknown" = "helium.desktop";
      };

      environment.sessionVariables.BROWSER = "helium";

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

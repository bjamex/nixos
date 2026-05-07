{ self, inputs, ... }: {

  flake.nixosModules.styxConfiguration = { pkgs, lib, ... }: {
    imports = [
      self.nixosModules.styxHardware
      self.nixosModules.niriStyx
      self.nixosModules.gaming
      self.nixosModules.pipewire
      self.nixosModules.fileManager
      self.nixosModules.kitty
      self.nixosModules.neovim
      self.nixosModules.llm
      self.nixosModules.theming
      self.nixosModules.insync
      self.nixosModules.swinHome
    ];

    # --- Nix ---
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.settings.auto-optimise-store = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    nixpkgs.config.allowUnfree = true;
    nixpkgs.overlays = [
      (final: prev: {
        stable = import inputs.nixpkgs-pinned {
          system = final.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        };
      })
    ];

    # --- Boot ---
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_latest;
    boot.kernelModules = [ "igc" ];

    # --- Networking ---
    networking.hostName = "styx";
    networking.networkmanager.enable = true;
    networking.firewall.enable = false;
    services.openssh.enable = false;
    services.tailscale = {
      enable = true;
      permitCertUid = "swin";
      extraUpFlags = [ "--accept-routes=false" "--snat-subnet-routes=false" ];
    };

    # --- Locale & Time ---
    time.timeZone = "Australia/Brisbane";
    i18n.defaultLocale = "en_AU.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS        = "en_AU.UTF-8";
      LC_IDENTIFICATION = "en_AU.UTF-8";
      LC_MEASUREMENT    = "en_AU.UTF-8";
      LC_MONETARY       = "en_AU.UTF-8";
      LC_NAME           = "en_AU.UTF-8";
      LC_NUMERIC        = "en_AU.UTF-8";
      LC_PAPER          = "en_AU.UTF-8";
      LC_TELEPHONE      = "en_AU.UTF-8";
      LC_TIME           = "en_AU.UTF-8";
    };

    # --- Hardware ---
    hardware.amdgpu.initrd.enable = true;

    # --- Bluetooth ---
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
    services.blueman.enable = true;

    # --- Audio (see pipewire.nix) ---

    # --- Scanning ---
    hardware.sane.enable = true;
    hardware.sane.extraBackends = [ pkgs.epsonscan2 ];

    # --- Printing ---
    services.printing.enable = true;
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    hardware.printers.ensureDefaultPrinter = "EPSON_SC_T3100_Series";
    hardware.printers.ensurePrinters = [{
      name = "EPSON_SC_T3100_Series";
      location = "Local";
      deviceUri = "dnssd://EPSON%20SC-T3100%20Series._ipp._tcp.local/?uuid=cfe92100-67c4-11d4-a45f-9caed3d3a501";
      model = "everywhere";
      ppdOptions.InputSlot = "Rear";
    }];

    # --- Virtualisation ---
    virtualisation.docker.enable = true;

    # --- Shell ---
    programs.bash.shellAliases.n = "nvim";

    # --- Programs ---
    security.polkit.enable = true;
    programs.appimage.enable = true;
    programs.appimage.binfmt = true;

    # --- Remote Access ---
    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
    };

    # --- Services ---
    services.flatpak.enable = true;

    # --- Users ---
    users.users.swin = {
      isNormalUser = true;
      description = "Brett James";
      extraGroups = [ "networkmanager" "wheel" "render" "video" "docker" "scanner" "lp" "disk" ];
      packages = with pkgs; [];
    };

    # --- Packages ---
    environment.systemPackages = with pkgs; [
      # Shell utilities
      (writeShellScriptBin "nwhich" "readlink -f $(which $1)")
      (writeShellScriptBin "cnwhich" "cat $(readlink -f $(which $1))")
      (writeShellScriptBin "md" "mkdir -p \"$1\" && cd \"$1\"")

      # Development
      git
      gh
      vscode-fhs
      claude-code

      # Terminal & System
      btop
      ncdu
      baobab
      fzf
      lazygit
      yazi

      # Internet & Communication
      inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.helium
      # mcp-nixos  # broken: aioboto3 dependency issue in nixpkgs
      qbittorrent
      thunderbird
      nordpass
      localsend

      # Media & Creative
      rapidraw
      obs-studio
      darktable
      jellyfin-tui
      loupe
      vlc
      inkscape
      pinta
      xournalpp
      davinci-resolve

      # Productivity
      impression
      libreoffice
      gnome-calculator
      pdfarranger
      freecad
      epsonscan2
      cisco-packet-tracer_9

      # Networking & Monitoring
      nethogs
      linssid
      moonlight-qt
      pamixer

      # AI
      lmstudio

    ];

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

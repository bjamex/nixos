{ self, inputs, ... }:
{

  flake.nixosModules.voidConfiguration =
    { pkgs, lib, ... }:
    {
      imports = [
        inputs.lix-module.nixosModules.lixFromNixpkgs
        self.nixosModules.voidHardware
        self.nixosModules.niriVoid
        self.nixosModules.gaming
        self.nixosModules.pipewire
        self.nixosModules.fileManager
        self.nixosModules.kitty
        self.nixosModules.neovim
        self.nixosModules.insync
        self.nixosModules.swinHome
        self.nixosModules.smb
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

      # --- Networking ---
      networking.hostName = "void";
      networking.networkmanager.enable = true;
      networking.firewall.enable = true;
      services.openssh.enable = false;
      services.tailscale = {
        enable = true;
        permitCertUid = "swin";
        extraUpFlags = [
          "--accept-routes=false"
          "--snat-subnet-routes=false"
        ];
      };

      # --- Locale & Time ---
      time.timeZone = "Australia/Brisbane";
      i18n.defaultLocale = "en_AU.UTF-8";
      i18n.extraLocaleSettings = {
        LC_ADDRESS = "en_AU.UTF-8";
        LC_IDENTIFICATION = "en_AU.UTF-8";
        LC_MEASUREMENT = "en_AU.UTF-8";
        LC_MONETARY = "en_AU.UTF-8";
        LC_NAME = "en_AU.UTF-8";
        LC_NUMERIC = "en_AU.UTF-8";
        LC_PAPER = "en_AU.UTF-8";
        LC_TELEPHONE = "en_AU.UTF-8";
        LC_TIME = "en_AU.UTF-8";
      };

      # --- Bluetooth ---
      hardware.bluetooth.enable = true;
      hardware.bluetooth.powerOnBoot = true;
      services.blueman.enable = true;
      systemd.services.bluetooth.serviceConfig.CapabilityBoundingSet = lib.mkForce [ "CAP_NET_ADMIN" "CAP_NET_BIND_SERVICE" ];

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
        openFirewall = true;
      };

      # --- Virtualisation ---
      virtualisation.docker.enable = true;

      # --- Services ---
      services.upower.enable = true;
      services.flatpak.enable = true;

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
        ];
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
        nh

        # Terminal & System
        btop
        ncdu
        baobab
        fzf
        lazygit
        yazi
        weathr

        # Internet & Communication
        inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.helium
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
        obsidian

        # Networking & Monitoring
        nethogs
        linssid
        moonlight-qt
        pamixer
        cifs-utils

        # AI
        lmstudio
      ];

      xdg.mime.defaultApplications = {
        "text/html" = "helium.desktop";
        "x-scheme-handler/http" = "helium.desktop";
        "x-scheme-handler/https" = "helium.desktop";
        "x-scheme-handler/about" = "helium.desktop";
        "x-scheme-handler/unknown" = "helium.desktop";
      };

      environment.sessionVariables.BROWSER = "helium";

      system.stateVersion = "25.11";
    };
}

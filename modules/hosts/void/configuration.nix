{ self, inputs, ... }: {

  flake.nixosModules.voidConfiguration = { pkgs, lib, ... }: {
    imports = [
      self.nixosModules.voidHardware
      self.nixosModules.niriVoid
      self.nixosModules.gaming
      self.nixosModules.pipewire
      self.nixosModules.fileManager
      self.nixosModules.kitty
      self.nixosModules.neovim
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

    # --- Boot ---
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_latest;

    # --- Networking ---
    networking.hostName = "void";
    networking.networkmanager.enable = true;
    services.openssh.enable = false;
    services.tailscale = {
      enable = true;
      permitCertUid = "swin";
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

    # --- Printing ---
    services.printing.enable = true;

    # --- Virtualisation ---
    virtualisation.docker.enable = true;

    # --- Users ---
    users.users.swin = {
      isNormalUser = true;
      description = "Brett James";
      extraGroups = [ "networkmanager" "wheel" "docker" ];
      packages = with pkgs; [];
    };

    # --- Packages ---
    environment.systemPackages = with pkgs; [
      # Development
      git
      claude-code

      # Terminal & System
      btop
      ncdu
      baobab
      fzf
      lazygit
      yazi

      # Internet & Communication
      google-chrome
      qbittorrent
      thunderbird
      nordpass
      localsend
      discord
      vesktop

      # Media & Creative
      obs-studio
      darktable
      jellyfin-tui
      xournalpp

      # Productivity
      pdfarranger
      freecad
      epsonscan2

      # Networking & Remote
      moonlight
      pamixer

      # Misc
      google-earth-pro
      sunshine
    ];

    system.stateVersion = "25.11";
  };
}

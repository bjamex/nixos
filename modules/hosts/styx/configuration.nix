{ self, inputs, ... }: {

  flake.nixosModules.styxConfiguration = { pkgs, lib, ... }: {
    # import any other modules from here
    imports = [
      self.nixosModules.styxHardware
      self.nixosModules.niri
      self.nixosModules.gaming
      self.nixosModules.pipewire
      self.nixosModules.kitty
      self.nixosModules.neovim
    ];

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    nix.settings.auto-optimise-store = true;
    
    # Bootloader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    # Use latest kernel.
    boot.kernelPackages = pkgs.linuxPackages_latest;

    networking.hostName = "styx"; # Define your hostname.
    # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    # Enable networking
    networking.networkmanager.enable = true;
    
    # Allow unfree software
    nixpkgs.config.allowUnfree = true;

    # SSH
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
    };
    
    # Set your time zone.
    time.timeZone = "Australia/Brisbane";

    # Select internationalisation properties.
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

    # GPU stuff
    hardware.amdgpu.initrd.enable = true;

    # services.xserver.enable = true;

    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
    services.blueman.enable = true;
    # hardware.amdgpu.amdvlk.enable = true;
 
    # Enable the GNOME Desktop Environment.
    # services.xserver.displayManager.gdm.enable = true;
    # services.xserver.desktopManager.gnome.enable = true;

    # Enable CUPS to print documents.
    services.printing.enable = true;

    # Enable sound with pipewire.
    # security.rtkit.enable = true;
    # services.pipewire = {
    #  enable = true;
    #  alsa.enable = true;
    #  alsa.support32Bit = true;
    #  pulse.enable = true;
    #  jack.enable = true;
    #    };

    # Define a user account.
    users.users.swin = {
      isNormalUser = true;
      description = "Brett James";
      extraGroups = [ "networkmanager" "wheel" ];
      packages = with pkgs; [
        # thunderbird
      ];
    };

    services.tailscale.enable = true;

    # List packages installed in system profile.
    environment.systemPackages = with pkgs; [
    discord
claude-code
    # mcp-nixos
    git
    google-chrome
    qbittorrent
    btop
    ncdu
    baobab
    fzf
    lazygit
    yazi    
    jellyfin-tui
    vesktop
    xournalpp
    obs-studio    
    # audio stuff
    pamixer 
    ];




    system.stateVersion = "25.11"; 

  }; # <--- Added this missing closing brace
}

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

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    nix.settings.auto-optimise-store = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    boot.kernelPackages = pkgs.linuxPackages_latest;

    networking.hostName = "void";
    networking.networkmanager.enable = true;

    nixpkgs.config.allowUnfree = true;

    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = true;
    };

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

    hardware.amdgpu.initrd.enable = true;

    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
    services.blueman.enable = true;

    services.printing.enable = true;

    users.users.swin = {
      isNormalUser = true;
      description = "Brett James";
      extraGroups = [ "networkmanager" "wheel" ];
      packages = with pkgs; [];
    };

    services.tailscale.enable = true;

    environment.systemPackages = with pkgs; [
      discord
      claude-code
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
      darktable
      pamixer
    ];

    system.stateVersion = "25.11";
  };
}

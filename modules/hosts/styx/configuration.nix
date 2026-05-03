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
      self.nixosModules.swinHome
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

    networking.hostName = "styx";
    networking.networkmanager.enable = true;

    nixpkgs.config.allowUnfree = true;

    services.openssh.enable = false;
    networking.firewall.enable = false;

    services.tailscale.enable = true;
    services.tailscale.permitCertUid = "swin";
    services.tailscale.extraUpFlags = [ "--accept-routes=false" "--snat-subnet-routes=false" ];

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
    # hardware.amdgpu.amdvlk.enable = true;

    services.printing.enable = true;

    services.flatpak.enable = true;

    virtualisation.docker.enable = true;


    services.sunshine = {
      enable = true;
      autoStart = true;
      capSysAdmin = true;
    };

    users.users.swin = {
      isNormalUser = true;
      description = "Brett James";
      extraGroups = [ "networkmanager" "wheel" "render" "video" "docker" ];
      packages = with pkgs; [];
    };

    environment.systemPackages = with pkgs; [
      claude-code
      inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.helium
      # mcp-nixos  # broken: aioboto3 dependency issue in nixpkgs
      git
      gh
      google-chrome
      qbittorrent
      btop
      ncdu
      baobab
      fzf
      lazygit
      yazi
      jellyfin-tui
      xournalpp
      obs-studio
      darktable
      pamixer
      epsonscan2
      freecad
      loupe
      nordpass
      localsend
      pdfarranger
      moonlight-qt
      inkscape
      pinta
      vlc
      davinci-resolve
      insync
      insync-nautilus
      thunderbird
      gnome-calculator
    ];

    fileSystems."/mnt/nvme2" = {
      device = "/dev/disk/by-uuid/eba90478-2582-4260-b65d-70cb4ffa1352";
      fsType = "ext4";
    };

    system.stateVersion = "25.11";
  };
}

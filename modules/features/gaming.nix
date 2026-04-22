{self, inputs, ...}: {
  flake.nixosModules.gaming = { pkgs, lib, ... }: {

    hardware.graphics.enable = lib.mkDefault true;

    programs = {
      gamemode.enable = true;
      gamescope.enable = true;
      steam = {
        # package = pkgs.steam.override {
        #   extraProfile = ''
        #     unset TZ
        #     # Allows Monado/WiVRn to be used
        #     export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
        #   '';
        # };
        enable = true;
        # extraCompatPackages = with pkgs; [
        #   proton-ge-bin
        # ];
        # extraPackages = with pkgs; [
        #   SDL2
        #   gamescope
        #   er-patcher
        # ];
        protontricks.enable = true;
      };
    };

    environment.systemPackages = with pkgs; [
      lutris
      steam-run
      dxvk
      gamescope
      mangohud
      r2modman
      heroic
      er-patcher
      bottles
      steamtinkerlaunch
      prismlauncher
      lsfg-vk
      lsfg-vk-ui
      # self.packages.${pkgs.system}.wow-launcher
    ];

    # persistence.cache.directories = [
    #   ".local/share/Hytale"
    #   ".local/share/hytale-launcher"
    #
    #   ".local/share/Steam"
    #   ".local/share/bottles"
    #   ".local/share/PrismLauncher"
    #   ".config/r2modmanPlus-local"
    #
    #   ".local/share/Terraria"
    #
    #   "Games"
    #
    #   ".config/heroic"
    # ];

    nix.settings = {
      substituters = ["https://nix-gaming.cachix.org"];
      trusted-public-keys = ["nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="];
    };
  };
}

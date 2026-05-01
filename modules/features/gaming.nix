{ self, inputs, ... }: {
  flake.nixosModules.gaming = { pkgs, lib, ... }: let
    pinnedPkgs = import inputs.nixpkgs-pinned {
      system = pkgs.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  in {
    imports = [ inputs.nix-gaming.nixosModules.pipewireLowLatency ];

    hardware.graphics.enable = lib.mkDefault true;
    hardware.graphics.enable32Bit = lib.mkDefault true;
    hardware.graphics.extraPackages = with pkgs; [ amdvlk rocmPackages.clr.icd ];
    hardware.graphics.extraPackages32 = with pkgs; [ driversi686Linux.amdvlk ];

    programs = {
      gamemode.enable = true;
      gamescope.enable = true;
      steam = {
        enable = true;
        protontricks.enable = true;
      };
    };

    environment.systemPackages = with pkgs; [
      pinnedPkgs.lutris
      steam-run
      dxvk
      gamescope
      mangohud
      r2modman
      heroic
      er-patcher
      # bottles  # broken: openldap test failure in nixpkgs
      steamtinkerlaunch
      prismlauncher
      lsfg-vk
      lsfg-vk-ui
      faugus-launcher
      xivlauncher
      rusty-path-of-building
    ];

    nix.settings = {
      substituters = [ "https://nix-gaming.cachix.org" ];
      trusted-public-keys = [ "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" ];
    };
  };
}

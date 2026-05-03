{ self, inputs, ... }: {
  flake.nixosModules.swinHome = { pkgs, ... }: {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.swin = {
      home.username = "swin";
      home.homeDirectory = "/home/swin";
      home.stateVersion = "25.11";
    };
  };
}

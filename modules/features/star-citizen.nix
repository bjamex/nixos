{ inputs, ... }: {
  flake.nixosModules.starCitizen = { ... }: {
    imports = [ inputs.nix-citizen.nixosModules.StarCitizen ];

    programs.rsi-launcher = {
      enable = true;
      gamescope.enable = true;
    };

    nix.settings = {
      substituters = [ "https://nix-citizen.cachix.org" ];
      trusted-public-keys = [ "nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo=" ];
    };
  };
}

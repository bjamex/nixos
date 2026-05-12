{ inputs, ... }: {
  flake.nixosModules.starCitizen = { ... }: {
    imports = [ inputs.nix-citizen.nixosModules.StarCitizen ];

    programs.rsi-launcher = {
      enable = true;
      gamescope = {
        enable = true;
        args = [ "--backend" "wayland" "-W" "2560" "-H" "1440" "-r" "144" "-f" ];
      };
    };

    nix.settings = {
      substituters = [ "https://nix-citizen.cachix.org" ];
      trusted-public-keys = [ "nix-citizen.cachix.org-1:lPMkWc2X8XD4/7YPEEwXKKBg+SVbYTVrAaLA2wQTKCo=" ];
    };
  };
}

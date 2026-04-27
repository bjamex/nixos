{ self, inputs, ... }: {
  flake.nixosModules.niriStyx = { config, pkgs, lib, ... }: {
    imports = [ self.nixosModules.niriBase ];

    perSystem = { pkgs, lib, self', ... }: {
      packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
        inherit pkgs;
        settings = self'.packages.niriCommonSettings // {
          # Styx desktop with DP-1 monitor
          outputs."DP-1".mode = "2560x1440@143.973";
        };
      };
    };
  };
}

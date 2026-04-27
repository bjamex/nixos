{ self, inputs, ... }: {
  flake.nixosModules.niriStyx = { config, pkgs, lib, ... }: {
    imports = [ self.nixosModules.niriBase ];
    programs.niri.package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiriStyx;
  };

  perSystem = { pkgs, lib, self', ... }: {
    packages.myNiriStyx = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      settings = self'.legacyPackages.niriCommonSettings // {
        outputs."DP-1".mode = "2560x1440@143.973";
      };
    };
  };
}

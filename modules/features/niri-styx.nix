{ self, inputs, ... }: {
  flake.nixosModules.niriStyx = { config, pkgs, lib, ... }: {
    imports = [ self.nixosModules.niriBase ];
    programs.niri.package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiriStyx;
  };

  perSystem = { pkgs, lib, self', ... }: {
    packages.myNiriStyx = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      v2-settings = true;
      settings = self'.legacyPackages.niriCommonSettings // {
        outputs."GIGA-BYTE TECHNOLOGY CO., LTD. M27Q 21410B002170".mode = "2560x1440@143.856";
      };
    };
  };
}

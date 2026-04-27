{ self, inputs, ... }: {
  flake.nixosModules.niriVoid = { config, pkgs, lib, ... }: {
    imports = [ self.nixosModules.niriBase ];
    programs.niri.package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiriVoid;
  };

  perSystem = { pkgs, lib, self', ... }: {
    packages.myNiriVoid = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      settings = self'.legacyPackages.niriCommonSettings;
    };
  };
}

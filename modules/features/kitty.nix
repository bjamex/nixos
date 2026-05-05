{ self, inputs, ... }: {

  flake.nixosModules.kitty = { pkgs, ... }: {
    environment.systemPackages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.myKitty
    ];
  };

  perSystem = { pkgs, ... }: {
    packages.myKitty = pkgs.kitty;
  };

}

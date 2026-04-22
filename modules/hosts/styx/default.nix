{ self, inputs, ... }: {
  flake.nixosConfigurations.styx = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.styxConfiguration
    ];
  };
}

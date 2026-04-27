{ self, inputs, ... }: {
  flake.nixosConfigurations.void = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.voidConfiguration
    ];
  };
}

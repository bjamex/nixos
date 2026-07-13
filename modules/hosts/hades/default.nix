{ self, inputs, ... }: {
  flake.nixosConfigurations.hades = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.disko.nixosModules.disko
      self.nixosModules.hadesConfiguration
    ];
  };
}

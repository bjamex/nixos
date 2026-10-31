{ self, inputs, ... }:
{
  flake.nixosConfigurations.builder = inputs.nixpkgs.lib.nixosSystem {
    modules = [ self.nixosModules.builderConfiguration ];
  };
}

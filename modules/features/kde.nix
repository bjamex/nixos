{ self, inputs, ... }:
{
  flake.nixosModules.kde =
    { ... }:
    {
      services.desktopManager.plasma6.enable = true;
      services.xserver.enable = true;
    };
}

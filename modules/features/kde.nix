{ self, inputs, ... }:
{
  flake.nixosModules.kde =
    { ... }:
    {
      services.desktopManager.plasma6.enable = true;
      services.xserver.enable = true;

      # Disable KWallet so KDE uses GNOME Keyring (via Secret Service) instead,
      # keeping one shared keystore across both Plasma and Niri sessions.
      environment.etc."xdg/kwalletrc".text = ''
        [Wallet]
        Enabled=false
      '';
    };
}

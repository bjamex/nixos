{ ... }:
{
  # Config lives in modules/users/dotfiles/kitty.conf (delivered via hjem in
  # swin.nix); this module just installs the terminal.
  flake.nixosModules.kitty =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.kitty ];
    };
}

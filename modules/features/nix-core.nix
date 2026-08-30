# Nix daemon policy shared by every host. Split out of common.nix because
# hades needs it too but must NOT pull in the rest of common.nix (that module
# is the styx/void *desktop* foundation). Before this existed the two copies
# had drifted apart only by a comment, and a GC-policy change meant editing
# both.
{ ... }:
{
  flake.nixosModules.nixCore =
    { ... }:
    {
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      nix.settings.auto-optimise-store = true;

      # hades is headless and rarely looked at, the desktops churn generations
      # fast — either way, without GC they accumulate indefinitely.
      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 14d";
      };

      nixpkgs.config.allowUnfree = true;
    };
}

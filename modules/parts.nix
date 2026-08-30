{ inputs, ... }:
{
  config = {
    systems = [
      "x86_64-linux"
    ];
    perSystem =
      { system, pkgs, ... }:
      {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # Makes `nix fmt` work on this repo. Same nixfmt (1.4.0) that
        # neovim.nix installs for in-editor formatting, so the CLI and the
        # editor can't disagree about style.
        formatter = pkgs.nixfmt;
      };
  };
}

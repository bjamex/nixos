{ ... }: {

  flake.nixosModules.shell =
    { pkgs, ... }:
    {
      programs.starship.enable = true;

      programs.bash.shellAliases = {
        ls = "eza --icons";
        ll = "eza -la --icons --git";
        # Rebuild this host and watch progress through nom (nix-output-monitor).
        # internal-json + -v feed nom the per-derivation build stream. No #attr:
        # nixos-rebuild picks the flake output matching the hostname, so the
        # same alias is correct on styx and void.
        rebuild = "sudo nixos-rebuild switch --flake /home/swin/styx --log-format internal-json -v |& nom --json";
      };

      environment.systemPackages = with pkgs; [
        eza
        unar # archive extractor (rar/zip/7z/…): `unar file.rar`, `lsar` to list
        nix-output-monitor # `nom` — live build/dependency progress for nix builds
      ];

      hjem.users.swin.files = {
        ".config/starship.toml".source = ../users/dotfiles/starship.toml;
      };
    };

}

{ self, inputs, ... }: {

  flake.nixosModules.shell =
    { pkgs, ... }:
    {
      programs.starship.enable = true;

      programs.bash.shellAliases = {
        ls = "eza --icons";
        ll = "eza -la --icons --git";
      };

      environment.systemPackages = with pkgs; [
        eza
        unar # archive extractor (rar/zip/7z/…): `unar file.rar`, `lsar` to list
      ];

      hjem.users.swin.files = {
        ".config/starship.toml".source = "${self}/modules/users/dotfiles/starship.toml";
      };
    };

}

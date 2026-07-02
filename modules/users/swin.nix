{ self, inputs, ... }: {
  flake.nixosModules.swinHome = { pkgs, ... }: {
    imports = [ inputs.hjem.nixosModules.default ];

    hjem.clobberByDefault = true;

    # Noctalia v5 ships its own hjem module exposing
    # `hjem.users.<name>.programs.noctalia` (config in modules/features/noctalia.nix).
    hjem.extraModules = [ inputs.noctalia.hjemModules.default ];

    hjem.users.swin = {
      directory = "/home/swin";
      files = {
        ".config/kitty/kitty.conf".source = ./dotfiles/kitty.conf;
        ".config/btop/btop.conf".source = ./dotfiles/btop/btop.conf;
        ".config/btop/themes/oxocarbon.theme".source = ./dotfiles/btop/themes/oxocarbon.theme;
        ".config/Code/User/settings.json".source = ./dotfiles/vscode/settings.json;
        ".config/gtk-3.0/settings.ini".source = ./dotfiles/gtk-3.0/settings.ini;
        ".config/gtk-4.0/settings.ini".source = ./dotfiles/gtk-4.0/settings.ini;
        ".config/gtk-4.0/gtk.css".source = ./dotfiles/gtk-4.0/gtk.css;
      };
    };
  };
}

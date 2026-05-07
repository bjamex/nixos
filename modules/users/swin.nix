{ self, inputs, ... }: {
  flake.nixosModules.swinHome = { pkgs, ... }: {
    imports = [ inputs.hjem.nixosModules.default ];

    hjem.clobberByDefault = true;

    hjem.users.swin = {
      directory = "/home/swin";
      files = {
        ".config/kitty/kitty.conf".source = ./dotfiles/kitty.conf;
        ".config/btop/btop.conf".source = ./dotfiles/btop.conf;
        ".config/Code/User/settings.json".source = ./dotfiles/vscode/settings.json;
      };
    };
  };
}

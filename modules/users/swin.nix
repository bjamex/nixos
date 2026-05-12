{ self, inputs, ... }: {
  flake.nixosModules.swinHome = { pkgs, ... }: {
    imports = [ inputs.hjem.nixosModules.default ];

    hjem.clobberByDefault = true;

    hjem.users.swin = {
      directory = "/home/swin";
      files = {
        ".config/kitty/kitty.conf".source = ./dotfiles/kitty.conf;
        ".config/btop/btop.conf".source = ./dotfiles/btop/btop.conf;
        ".config/btop/themes/oxocarbon.theme".source = ./dotfiles/btop/themes/oxocarbon.theme;
        ".config/Code/User/settings.json".source = ./dotfiles/vscode/settings.json;
        ".config/nvim/init.lua".source = ./dotfiles/nvim/init.lua;
        ".config/nvim/lua/config/lazy.lua".source = ./dotfiles/nvim/lua/config/lazy.lua;
        ".config/nvim/lua/config/options.lua".source = ./dotfiles/nvim/lua/config/options.lua;
        ".config/nvim/lua/config/keymaps.lua".source = ./dotfiles/nvim/lua/config/keymaps.lua;
        ".config/nvim/lua/config/autocmds.lua".source = ./dotfiles/nvim/lua/config/autocmds.lua;
        ".config/nvim/lua/plugins/init.lua".source = ./dotfiles/nvim/lua/plugins/init.lua;
        ".config/gtk-3.0/settings.ini".source = ./dotfiles/gtk-3.0/settings.ini;
        ".config/gtk-4.0/settings.ini".source = ./dotfiles/gtk-4.0/settings.ini;
      };
    };
  };
}

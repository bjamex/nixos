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
        ".config/nvim/init.lua".source = ./dotfiles/nvim/init.lua;
        ".config/nvim/lua/config/lazy.lua".source = ./dotfiles/nvim/lua/config/lazy.lua;
        ".config/nvim/lua/config/options.lua".source = ./dotfiles/nvim/lua/config/options.lua;
        ".config/nvim/lua/config/keymaps.lua".source = ./dotfiles/nvim/lua/config/keymaps.lua;
        ".config/nvim/lua/config/autocmds.lua".source = ./dotfiles/nvim/lua/config/autocmds.lua;
        ".config/nvim/lua/plugins/init.lua".source = ./dotfiles/nvim/lua/plugins/init.lua;
      };
    };
  };
}

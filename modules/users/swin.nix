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
        ".config/nvim/init.lua".source = ./dotfiles/nvim/init.lua;
        ".config/nvim/lua/config/lazy.lua".source = ./dotfiles/nvim/lua/config/lazy.lua;
        ".config/nvim/lua/config/options.lua".source = ./dotfiles/nvim/lua/config/options.lua;
        ".config/nvim/lua/config/keymaps.lua".source = ./dotfiles/nvim/lua/config/keymaps.lua;
        ".config/nvim/lua/config/autocmds.lua".source = ./dotfiles/nvim/lua/config/autocmds.lua;
        ".config/nvim/lua/plugins/init.lua".source = ./dotfiles/nvim/lua/plugins/init.lua;
        ".config/nvim/lua/plugins/claudecode.lua".source = ./dotfiles/nvim/lua/plugins/claudecode.lua;
        ".config/gtk-3.0/settings.ini".source = ./dotfiles/gtk-3.0/settings.ini;
        ".config/gtk-4.0/settings.ini".source = ./dotfiles/gtk-4.0/settings.ini;
        ".config/gtk-4.0/gtk.css".source = ./dotfiles/gtk-4.0/gtk.css;
        ".local/share/applications/nvim.desktop".text = ''
          [Desktop Entry]
          Name=Neovim wrapper
          GenericName=Text Editor
          Comment=Edit text files
          TryExec=nvim
          Exec=kitty -e nvim %F
          Terminal=false
          Type=Application
          Keywords=Text;editor;
          Icon=nvim
          Categories=Utility;TextEditor;Development;
          MimeType=text/english;text/plain;text/x-makefile;text/x-c++hdr;text/x-c++src;text/x-chdr;text/x-csrc;text/x-java;text/x-moc;text/x-pascal;text/x-tcl;text/x-tex;application/x-shellscript;text/x-c;text/x-c++;
        '';
      };
    };
  };
}

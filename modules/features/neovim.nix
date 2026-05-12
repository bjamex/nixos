{ self, inputs, ... }: {

  flake.nixosModules.neovim = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      neovim
      wl-clipboard
      gcc
      tree-sitter
      ripgrep
      fd
      nodejs
      unzip
      trash-cli

      # LSP servers and linters (Mason can't install binaries on NixOS)
      nil                    # nil_ls  — Nix
      lua-language-server    # lua_ls  — Lua
      statix                 # Nix linter / code actions
    ];
  };
}

{ self, inputs, ... }: {

  flake.nixosModules.neovim = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      neovim
      gcc
      tree-sitter
      ripgrep
      fd
      nodejs
      unzip
      trash-cli

      # LSP servers (Mason can't install binaries on NixOS)
      nil                    # nil_ls  — Nix
      lua-language-server    # lua_ls  — Lua
    ];
  };
}

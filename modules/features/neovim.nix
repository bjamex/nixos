{ self, inputs, ... }: {

  flake.nixosModules.neovim = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      neovim
      # LazyVim runtime dependencies
      gcc         # treesitter compilation
      tree-sitter # treesitter CLI
      ripgrep     # live grep
      fd          # file finder
      nodejs      # LSP servers via mason
      unzip       # mason package extraction
      trash-cli   # safe file deletion in explorer
    ];
  };
}

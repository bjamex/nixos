{ self, inputs, ... }: {

  flake.nixosModules.neovim = { pkgs, lib, ... }: {
    # Neovim set up the way Omarchy does it: the LazyVim distribution driven by
    # lazy.nvim. Nix only provides the neovim binary, the build/CLI tools
    # lazy.nvim + nvim-treesitter shell out to, and the language servers; the
    # actual plugins are installed by lazy.nvim at runtime into
    # ~/.local/share/nvim (imperative, exactly like Omarchy — and like the Doom
    # setup this replaced).
    #
    # The one deviation from vanilla Omarchy: LazyVim installs LSP servers via
    # Mason, whose prebuilt binaries don't run on NixOS. Mason is disabled in
    # lua/plugins/nixos.lua and the servers come from Nix instead (below).

    environment.variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    # LazyVim's UI (and many plugins) want the Nerd Font symbol glyphs.
    fonts.packages = [ pkgs.nerd-fonts.symbols-only ];

    # LazyVim lua config, delivered read-only through hjem so both hosts stay in
    # sync. NOTE: these become read-only /nix/store symlinks — edit the repo
    # copies under modules/users/dotfiles/nvim, then rebuild. lazy.nvim's
    # lazy-lock.json and LazyVim's lazyvim.json (:LazyExtras) are deliberately
    # NOT listed here, so they stay writable at ~/.config/nvim for runtime use.
    hjem.users.swin.files = {
      ".config/nvim/init.lua".source = "${self}/modules/users/dotfiles/nvim/init.lua";
      ".config/nvim/lua/config/lazy.lua".source =
        "${self}/modules/users/dotfiles/nvim/lua/config/lazy.lua";
      ".config/nvim/lua/config/options.lua".source =
        "${self}/modules/users/dotfiles/nvim/lua/config/options.lua";
      ".config/nvim/lua/config/keymaps.lua".source =
        "${self}/modules/users/dotfiles/nvim/lua/config/keymaps.lua";
      ".config/nvim/lua/config/autocmds.lua".source =
        "${self}/modules/users/dotfiles/nvim/lua/config/autocmds.lua";
      ".config/nvim/lua/plugins/theme.lua".source =
        "${self}/modules/users/dotfiles/nvim/lua/plugins/theme.lua";
      ".config/nvim/lua/plugins/nixos.lua".source =
        "${self}/modules/users/dotfiles/nvim/lua/plugins/nixos.lua";
    };

    environment.systemPackages = with pkgs; [
      neovim

      # lazy.nvim / nvim-treesitter / LazyVim runtime tooling
      git
      ripgrep
      fd
      lazygit
      gcc # nvim-treesitter compiles parsers at runtime
      gnumake
      nodejs # many plugins / LSP shims
      unzip
      wl-clipboard # system clipboard integration under Wayland
      tree-sitter

      # Language servers (replacing Mason) + formatters
      lua-language-server
      stylua
      nixd
      nixfmt
      pyright
    ];
  };
}

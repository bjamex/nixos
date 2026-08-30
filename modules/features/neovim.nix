{ ... }: {

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
      ".config/nvim/init.lua".source = ../users/dotfiles/nvim/init.lua;
      ".config/nvim/lua/config/lazy.lua".source = ../users/dotfiles/nvim/lua/config/lazy.lua;
      ".config/nvim/lua/config/options.lua".source = ../users/dotfiles/nvim/lua/config/options.lua;
      ".config/nvim/lua/config/keymaps.lua".source = ../users/dotfiles/nvim/lua/config/keymaps.lua;
      ".config/nvim/lua/config/autocmds.lua".source = ../users/dotfiles/nvim/lua/config/autocmds.lua;
      ".config/nvim/lua/plugins/theme.lua".source = ../users/dotfiles/nvim/lua/plugins/theme.lua;
      ".config/nvim/lua/plugins/nixos.lua".source = ../users/dotfiles/nvim/lua/plugins/nixos.lua;
      ".config/nvim/lua/plugins/layout.lua".source = ../users/dotfiles/nvim/lua/plugins/layout.lua;
      ".config/nvim/lua/plugins/herdr.lua".source = ../users/dotfiles/nvim/lua/plugins/herdr.lua;
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

      # Language servers / linters / formatters (replacing Mason). LazyVim's
      # enabled lang extras (see ~/.config/nvim/lazyvim.json) auto-detect these
      # on PATH, so mostly no lua config is needed — just the binary here.
      # Two enabled extras have no clean nixpkgs binary and are left to the user
      # to disable if unused: lang.typescript.tsgo (@typescript/native-preview)
      # and lang.twig (no packaged twig LSP).
      lua-language-server # :lang (lua config itself)
      stylua

      nixd # :lang nix
      statix
      deadnix
      nixfmt

      pyright # :lang python
      ruff

      astro-language-server # :lang astro — astro-ls

      # :lang typescript (vtsls is LazyVim's default) + json/eslint/html/css
      vtsls
      typescript
      typescript-language-server
      vscode-langservers-extracted # json, eslint, html, css LSPs
      biome # :lang typescript.biome
      oxlint # :lang typescript.oxc
      prettierd # web formatting (conform/none-ls)

      yaml-language-server # :lang yaml

      # :lang docker
      dockerfile-language-server
      docker-compose-language-service
      hadolint

      rust-analyzer # :lang rust

      # :lang sql (nixpkgs ships sqls, not the node sql-language-server)
      sqls
      sqlfluff

      # :lang typst
      tinymist
      typst
      typstyle
    ];
  };
}

return {
  {
    "nyoom-engineering/oxocarbon.nvim",
    lazy = false,
    priority = 1000,
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "oxocarbon" } },

  -- LSP servers are installed via nixpkgs on NixOS, not Mason
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        nil_ls = { mason = false },
        lua_ls = { mason = false },
      },
    },
  },
  {
    "williamboman/mason-lspconfig.nvim",
    opts = { automatic_installation = false },
  },
}

return {
  {
    "nyoom-engineering/oxocarbon.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "oxocarbon",
        callback = function()
          -- Replace oxocarbon's pinks (#ee5396, #ff7eb6) with orange tones
          local overrides = {
            Keyword                    = { fg = "#ff832b" },
            Statement                  = { fg = "#ff832b" },
            Operator                   = { fg = "#ff832b" },
            Special                    = { fg = "#ffa057" },
            Tag                        = { fg = "#ff832b" },
            ["@punctuation.delimiter"] = { fg = "#ff832b" },
            ["@variable"]              = { fg = "#f2f4f8" },
            ["@property"]              = { fg = "#f2f4f8" },
            ["@function.lua"]          = { fg = "#82cfff" },
            ["@function.call"]                  = { fg = "#82cfff" },
            ["@function.builtin"]               = { fg = "#33b1ff" },
            ["@markup.heading.1.markdown"]      = { fg = "#78a9ff", bold = true },
            ["@markup.heading.2.markdown"]      = { fg = "#82cfff", bold = true },
            ["@markup.heading.3.markdown"]      = { fg = "#33b1ff", bold = true },
            ["@markup.heading.4.markdown"]      = { fg = "#08bdba", bold = true },
            ["@markup.heading.5.markdown"]      = { fg = "#3ddbd9" },
            ["@markup.heading.6.markdown"]      = { fg = "#3ddbd9" },
          }
          for group, hl in pairs(overrides) do
            vim.api.nvim_set_hl(0, group, hl)
          end
        end,
      })
    end,
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

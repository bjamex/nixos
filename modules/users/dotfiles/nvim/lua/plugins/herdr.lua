-- herdr-splits.nvim: seamless C-h/j/k/l navigation and M-h/j/k/l resizing across
-- Neovim splits AND herdr panes, so they behave like one editor when nvim runs
-- inside a herdr pane.
--
-- `cond` gates the whole plugin on HERDR_ENV, which herdr sets in its panes — so
-- outside herdr this loads nothing and leaves C-h/j/k/l untouched.
--
-- The herdr side is imperative (like lazy.nvim installing plugins at runtime),
-- run once after `nixos-rebuild switch`:
--   herdr plugin install lmilojevicc/herdr-splits.nvim
--   # add the ctrl/alt h,j,k,l plugin_action binds to ~/.config/herdr/config.toml
--   herdr server reload-config
return {
  {
    "lmilojevicc/herdr-splits.nvim",
    cond = vim.env.HERDR_ENV == "1",
    event = "VeryLazy",
    build = 'lua require("herdr-splits").sync_herdr()',
    config = function()
      require("herdr-splits").setup({
        default_amount = 0.03,
        neovim_amount = 3,
        at_edge = "wrap",
        ignored_buftypes = { "nofile", "quickfix", "prompt", "help", "terminal" },
        ignored_filetypes = {
          "NvimTree",
          "neo-tree",
          "snacks_dashboard",
          "snacks_explorer",
          "snacks_picker",
          "dadbod-ui",
          "dbout",
          "aerial",
          "Outline",
          "Trouble",
          "quickfix",
        },
        move_cursor_same_row = false,
        floating_zindex_max = 50,
        unzoom_on_nav = true,
        nav_at_edge = "wrap",
        nav_keys = { left = "<C-h>", down = "<C-j>", up = "<C-k>", right = "<C-l>" },
        resize_keys = { left = "<M-h>", down = "<M-j>", up = "<M-k>", right = "<M-l>" },
        auto_sync_herdr = true,
      })
    end,
    keys = {
      { "<C-h>", function() require("herdr-splits").move_cursor_left() end, desc = "Navigate left" },
      { "<C-j>", function() require("herdr-splits").move_cursor_down() end, desc = "Navigate down" },
      { "<C-k>", function() require("herdr-splits").move_cursor_up() end, desc = "Navigate up" },
      { "<C-l>", function() require("herdr-splits").move_cursor_right() end, desc = "Navigate right" },
      { "<M-h>", function() require("herdr-splits").resize_left() end, desc = "Resize left" },
      { "<M-j>", function() require("herdr-splits").resize_down() end, desc = "Resize down" },
      { "<M-k>", function() require("herdr-splits").resize_up() end, desc = "Resize up" },
      { "<M-l>", function() require("herdr-splits").resize_right() end, desc = "Resize right" },
    },
  },
}

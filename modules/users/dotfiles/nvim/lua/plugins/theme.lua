-- Colorscheme: oxocarbon (matches btop/GTK), rendered transparent so the
-- terminal's translucency shows the wallpaper through Neovim instead of a flat
-- near-black (#161616) slab. To go opaque again, drop the transparency loop in
-- the `init` block; to use a different scheme, swap the plugin + colorscheme.
--
-- Tweaks on top of stock oxocarbon: its comments and line numbers are painted
-- a very dark grey (#525252) that's hard to read, so we recolour them to
-- oxocarbon's green (#42be65) for a greener, more legible look while leaving
-- the rest of the palette alone. #2e8547 is a dimmer shade of the same hue for
-- purely decorative text.
return {
  { "nyoom-engineering/oxocarbon.nvim" },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "oxocarbon",
    },
    -- Runs before plugins load, so the ColorScheme autocmd is in place before
    -- oxocarbon is applied (and re-applies on any later colorscheme change).
    init = function()
      -- Groups whose background we clear for transparency.
      local transparent = {
        "Normal",
        "NormalNC",
        "NormalFloat",
        "FloatBorder",
        "FloatTitle",
        "SignColumn",
        "FoldColumn",
        "MsgArea",
        "TelescopeNormal",
        "TelescopeBorder",
        "NeoTreeNormal",
        "NeoTreeNormalNC",
        "WhichKeyFloat",
        "WhichKeyNormal",
        "LazyNormal",
        "SnacksNormal",
        "SnacksNormalNC",
        "SnacksPickerNormal",
        "SnacksDashboardNormal",
      }
      -- Foreground overrides: lift the dark-grey text and push it green.
      local overrides = {
        -- Lift main text from oxocarbon's dim #d0d0d0 to its brightest white.
        Normal = { fg = "#f2f4f8", bg = "none" },
        NormalNC = { fg = "#f2f4f8", bg = "none" },
        Comment = { fg = "#42be65", italic = true, bg = "none" },
        ["@comment"] = { fg = "#42be65", italic = true, bg = "none" },
        LineNr = { fg = "#42be65", bg = "none" },
        CursorLineNr = { fg = "#42be65", bold = true, bg = "none" },
        NonText = { fg = "#2e8547", bg = "none" },
        -- Dimmed directory prefix in the Snacks file picker.
        SnacksPickerDir = { fg = "#42be65", bg = "none" },
        SnacksPickerPathHidden = { fg = "#2e8547", bg = "none" },
      }
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          -- Clear only the background (guibg=NONE) so oxocarbon's foreground
          -- colours are preserved; nvim_set_hl would replace the whole group.
          for _, g in ipairs(transparent) do
            vim.cmd(("highlight %s guibg=NONE ctermbg=NONE"):format(g))
          end
          for g, spec in pairs(overrides) do
            vim.api.nvim_set_hl(0, g, spec)
          end
        end,
      })
    end,
  },
}

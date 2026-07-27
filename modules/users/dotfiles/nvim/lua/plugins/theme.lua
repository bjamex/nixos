-- Colorscheme: oxocarbon (matches btop/GTK), rendered transparent so the
-- terminal's translucency shows the wallpaper through Neovim instead of a flat
-- near-black (#161616) slab. To go opaque again, drop the `init` block below;
-- to use a different scheme, swap the plugin + colorscheme string.
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
      local groups = {
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
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          -- Clear only the background (guibg=NONE) so oxocarbon's foreground
          -- colours are preserved; nvim_set_hl would replace the whole group.
          for _, g in ipairs(groups) do
            vim.cmd(("highlight %s guibg=NONE ctermbg=NONE"):format(g))
          end
        end,
      })
    end,
  },
}

-- Colorscheme: eldritch, matching the system theme (Noctalia / kitty / GTK).
-- eldritch has a native `transparent` option, so we let the theme itself clear
-- every background — editor, dashboard, floats, and the :terminal — instead of
-- chasing individual groups by hand (which left black patches when the theme
-- changed). The terminal's translucency then shows the wallpaper through Neovim.
-- To go opaque, flip `transparent = false`; to switch schemes, swap the plugin
-- + the LazyVim `colorscheme` below.
return {
  {
    "eldritch-theme/eldritch.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = true,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "eldritch",
    },
  },
}

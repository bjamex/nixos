-- LazyVim starter entry point. Bootstraps lazy.nvim + the LazyVim distro.
-- Delivered read-only via hjem (see modules/features/neovim.nix); lazy.nvim
-- installs the actual plugins at runtime into ~/.local/share/nvim, and writes
-- ~/.config/nvim/lazy-lock.json + lazyvim.json (both intentionally NOT
-- hjem-managed so they stay writable).
require("config.lazy")

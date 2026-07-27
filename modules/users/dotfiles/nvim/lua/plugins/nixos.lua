-- NixOS adaptation of the Omarchy/LazyVim defaults.
--
-- LazyVim installs LSP servers via Mason, but Mason downloads prebuilt
-- dynamically-linked binaries that will not run on NixOS. So we disable Mason
-- entirely and rely on language servers provided declaratively through Nix
-- (see modules/features/neovim.nix), which nvim-lspconfig picks up from PATH.
return {
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },

  -- Configure the Nix-provided servers directly. LazyVim already sets up
  -- lua_ls; nixd and pyright are declared here so lspconfig starts them from
  -- PATH without Mason. Extend `servers` as you add more LSPs in neovim.nix.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        nixd = {},
        pyright = {},
      },
    },
  },
}

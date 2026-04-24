{ self, inputs, ... }: {

  flake.nixosModules.neovim = { pkgs, ... }: {
    environment.systemPackages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.myNeovim
    ];
  };

  perSystem = { pkgs, system, ... }: {
    packages.myNeovim = inputs.nixvim.legacyPackages.${system}.makeNixvimWithModule {
      module = {
        globals.mapleader = " ";
        viAlias = true;
        vimAlias = true;

        opts = {
          number = true;
          relativenumber = true;
          shiftwidth = 2;
          tabstop = 2;
          expandtab = true;
          smartindent = true;
          wrap = false;
          termguicolors = true;
          signcolumn = "yes";
          scrolloff = 8;
          updatetime = 50;
          cursorline = true;
        };

        colorschemes.catppuccin = {
          enable = true;
          settings.flavour = "mocha";
        };

        plugins = {
          lualine = {
            enable = true;
            settings.options.theme = "catppuccin";
          };

          bufferline.enable = true;

          neo-tree.enable = true;

          telescope = {
            enable = true;
            keymaps = {
              "<leader>ff" = "find_files";
              "<leader>fg" = "live_grep";
              "<leader>fb" = "buffers";
              "<leader>fh" = "help_tags";
              "<leader>gf" = "git_files";
            };
          };

          treesitter = {
            enable = true;
            settings.highlight.enable = true;
          };

          lsp = {
            enable = true;
            servers = {
              nixd.enable = true;
              lua_ls.enable = true;
            };
          };

          cmp = {
            enable = true;
            settings = {
              sources = [
                { name = "nvim_lsp"; }
                { name = "luasnip"; }
                { name = "buffer"; }
                { name = "path"; }
              ];
              mapping = {
                "<C-Space>" = "cmp.mapping.complete()";
                "<C-e>" = "cmp.mapping.close()";
                "<CR>" = "cmp.mapping.confirm({ select = true })";
                "<Tab>" = ''cmp.mapping(cmp.mapping.select_next_item(), {"i", "s"})'';
                "<S-Tab>" = ''cmp.mapping(cmp.mapping.select_prev_item(), {"i", "s"})'';
              };
            };
          };

          luasnip.enable = true;
          cmp-nvim-lsp.enable = true;
          cmp-buffer.enable = true;
          cmp-path.enable = true;
          cmp_luasnip.enable = true;

          gitsigns.enable = true;

          nvim-autopairs.enable = true;
          which-key.enable = true;
          comment.enable = true;
          indent-blankline.enable = true;
          web-devicons.enable = true;
        };

        keymaps = [
          { mode = "n"; key = "<leader>e"; action = ":Neotree toggle<CR>"; options.silent = true; }
          { mode = "n"; key = "<C-h>"; action = "<C-w>h"; }
          { mode = "n"; key = "<C-j>"; action = "<C-w>j"; }
          { mode = "n"; key = "<C-k>"; action = "<C-w>k"; }
          { mode = "n"; key = "<C-l>"; action = "<C-w>l"; }
          { mode = "n"; key = "<leader>bd"; action = ":bd<CR>"; options.silent = true; }
        ];
      };
    };
  };

}

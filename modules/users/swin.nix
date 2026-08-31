{ self, inputs, ... }: {
  flake.nixosModules.swinHome = { pkgs, ... }: {
    imports = [ inputs.hjem.nixosModules.default ];

    hjem.clobberByDefault = true;

    # Noctalia v5 ships its own hjem module exposing
    # `hjem.users.<name>.programs.noctalia` (config in modules/features/noctalia.nix).
    hjem.extraModules = [ inputs.noctalia.hjemModules.default ];

    hjem.users.swin = {
      directory = "/home/swin";
      files = {
        # `type = "copy"` on every config a Noctalia template post-hook rewrites
        # (see the templates block in modules/features/noctalia.nix). Those hooks
        # edit the app's own config to point at the generated theme, and a
        # read-only /nix/store symlink makes them fail — which is exactly what
        # silently stranded btop on the old palette. The repo copies already
        # carry the final state, so on a fresh activation the hooks are no-ops.
        ".config/kitty/kitty.conf" = {
          source = ./dotfiles/kitty.conf;
          type = "copy";
        };
        ".config/btop/btop.conf" = {
          source = ./dotfiles/btop/btop.conf;
          type = "copy";
        };
        ".config/gtk-3.0/gtk.css" = {
          source = ./dotfiles/gtk-3.0/gtk.css;
          type = "copy";
        };
        ".config/gtk-4.0/gtk.css" = {
          source = ./dotfiles/gtk-4.0/gtk.css;
          type = "copy";
        };

        # Not touched by any template — plain symlinks are fine.
        ".config/gtk-3.0/settings.ini".source = ./dotfiles/gtk-3.0/settings.ini;
        ".config/gtk-4.0/settings.ini".source = ./dotfiles/gtk-4.0/settings.ini;
      };
    };
  };
}

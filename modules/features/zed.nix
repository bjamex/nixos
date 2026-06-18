{ ... }:
{
  # Zed — high-performance, Wayland-native editor from the Atom/Tree-sitter folks.
  # Chosen as the GUI companion to terminal Claude Code: Zed bundles the
  # `claude-code-acp` adapter and talks to Claude Code over the Agent Client
  # Protocol (Agent Panel, ctrl-?), so the same CLI agent gets editor-grade
  # context (selection, diffs, diagnostics) without an Electron/XWayland stack.
  #
  # NixOS gotcha: the ACP adapter (and most extensions) run under Node, and Zed
  # otherwise downloads a glibc-linked Node into ~/.local/share/zed that won't
  # execute on NixOS. We pin Zed at a Nix-provided Node via `settings.node`,
  # which is the clean fix and avoids reaching for `zed-editor-fhs`.
  #
  # Config is delivered through hjem (this repo's dotfile manager), matching the
  # zen / matcha modules. Zed still writes its own state into ~/.config/zed and
  # ~/.local/share/zed; we only own settings.json.
  flake.nixosModules.zed =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.zed-editor ];

      hjem.users.swin.files.".config/zed/settings.json".text = builtins.toJSON {
        # Point Zed's runtime at nixpkgs Node so the Claude Code ACP adapter and
        # extensions actually run on NixOS.
        node = {
          path = "${pkgs.nodejs}/bin/node";
          npm_path = "${pkgs.nodejs}/bin/npm";
        };

        # Nix owns updates; don't let Zed self-update or nag.
        auto_update = false;

        telemetry = {
          diagnostics = false;
          metrics = false;
        };

        theme = "One Dark";
        ui_font_size = 15;
        buffer_font_size = 14;

        # You drive Neovim already (`n` alias) — flip this to true for modal
        # editing inside Zed if the muscle memory carries over.
        vim_mode = false;
      };
    };
}

{ inputs, ... }:
{
  # herdr — a terminal multiplexer built for AI coding agents: each agent
  # (Claude Code, Codex, OpenCode, …) runs in its own real PTY pane, sessions
  # persist and can be re-attached over SSH, and it tracks each pane's agent
  # state (blocked / working / done / idle). Think "tmux for the agent era".
  #
  # Not in nixpkgs — pulled from the upstream flake (inputs.herdr). It's a source
  # build (Rust + zig compiling vendored libghostty-vt) with no public binary
  # cache, so the first rebuild compiles it; later rebuilds reuse the store path.
  #
  # Neovim integration (C-h/j/k/l seamless split/pane navigation) lives in the
  # LazyVim config at modules/users/dotfiles/nvim/lua/plugins/herdr.lua, wired in
  # through the neovim module's hjem block.
  flake.nixosModules.herdr =
    { pkgs, ... }:
    {
      environment.systemPackages = [ inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default ];

      # herdr's config.toml is a read-only *input* (herdr never writes back to
      # it — settings, plugins.json, sessions and sockets all live in separate
      # writable files), so it's safe to deliver as a read-only hjem symlink.
      # This carries the herdr-splits Ctrl/Alt+hjkl keybinds so a fresh machine
      # gets pane<->nvim-split navigation without hand-editing. Edit the repo
      # copy then rebuild; run `herdr server reload-config` to apply live.
      #
      # Still imperative (like lazy.nvim installing plugins at runtime): the
      # herdr-splits plugin itself, installed once with
      #   herdr plugin install lmilojevicc/herdr-splits.nvim
      hjem.users.swin.files.".config/herdr/config.toml".source =
        ../users/dotfiles/herdr/config.toml;
    };
}

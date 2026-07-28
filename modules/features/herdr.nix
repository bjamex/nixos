{ self, inputs, ... }:
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
      environment.systemPackages = [ inputs.herdr.packages.${pkgs.system}.default ];
    };
}

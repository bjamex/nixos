{ self, inputs, ... }:
{
  # Focus Rite — an eldritch Pomodoro timer as a Noctalia v5 bar widget.
  #
  # Noctalia loads local plugins from $XDG_DATA_HOME/noctalia/plugins/<plugin>/,
  # so the manifest + Luau entry land there via hjem (declarative, reproducible).
  # The plugin still has to be *enabled* and *placed on the bar* through Noctalia
  # Settings → Plugins (that lives in the GUI-managed settings.toml state, which
  # this config deliberately doesn't fight — see noctalia.nix).
  flake.nixosModules.focusWidget =
    { ... }:
    {
      hjem.users.swin.files = {
        ".local/share/noctalia/plugins/styx-focus/plugin.toml".source =
          ./focus-widget/plugin.toml;
        ".local/share/noctalia/plugins/styx-focus/focus.luau".source =
          ./focus-widget/focus.luau;
      };
    };
}

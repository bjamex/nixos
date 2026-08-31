{ ... }:
{
  # wayscriber — screen annotation overlay for Wayland (draw on top of whatever
  # is on screen, à la gromit-mpx / Epic Pen).
  #
  # Runs as a daemon so the toggle is instant: `--active` would spawn a fresh
  # process and re-create the wlr-layer-shell surface on every keypress, and the
  # daemon is also what holds the session (boards/pages) between activations.
  # It is started from Hyprland rather than a systemd user service so it
  # inherits WAYLAND_DISPLAY / HYPRLAND_INSTANCE_SIGNATURE — see
  # myHyprland.extraStartupExec's own documentation.
  flake.nixosModules.wayscriber =
    { pkgs, ... }:
    let
      wayscriber = "${pkgs.wayscriber}/bin/wayscriber";
    in
    {
      environment.systemPackages = [ pkgs.wayscriber ];

      myHyprland.extraStartupExec = [ "${wayscriber} --daemon" ];

      # Upstream suggests SUPER+D for the toggle, but that is Discord here, so
      # the whole set lives in the otherwise-unused SUPER+ALT namespace.
      myHyprland.extraBindsLua = ''
        -- wayscriber: annotate the screen
        hl.bind(mod .. " + ALT + D", hl.dsp.exec_cmd("${wayscriber} --daemon-toggle"))
        hl.bind(mod .. " + ALT + S", hl.dsp.exec_cmd("${wayscriber} --daemon-toggle --freeze"))
        hl.bind(mod .. " + ALT + L", hl.dsp.exec_cmd("${wayscriber} --light-toggle"))
        -- Hold-to-draw: the overlay only swallows input while the key is held,
        -- so the release bind is not optional — without it light mode stays
        -- armed and clicks stop reaching the app underneath.
        hl.bind(mod .. " + ALT + F", hl.dsp.exec_cmd("${wayscriber} --light-draw-on"))
        hl.bind(mod .. " + ALT + F", hl.dsp.exec_cmd("${wayscriber} --light-draw-off"), { release = true })
      '';
    };
}

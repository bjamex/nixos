{ self, inputs, ... }: {

  flake.nixosModules.focus =
    { pkgs, ... }:
    let
      # Wrap the Python TUI so `notify-send` (libnotify) is on its PATH at
      # runtime, regardless of what else is installed.
      focus = pkgs.writeShellApplication {
        name = "focus";
        # libnotify → notify-send (whispers); pulseaudio → paplay (the drone,
        # routed through pipewire-pulse).
        runtimeInputs = [ pkgs.python3 pkgs.libnotify pkgs.pulseaudio ];
        text = ''exec python3 ${./focus.py} "$@"'';
      };
    in
    {
      environment.systemPackages = [ focus ];
    };

}

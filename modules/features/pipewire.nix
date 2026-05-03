{ self, inputs, ... }: {

  flake.nixosModules.pipewire = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.crosspipe pkgs.easyeffects ];
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    services.pipewire.extraConfig.pipewire."mic-mono" = {
      "context.modules" = [
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.description" = "Mono Mic";
            "capture.props" = {
              "node.name" = "mono-mic-capture";
              "audio.position" = [ "FL" ];
            };
            "playback.props" = {
              "node.name" = "mono-mic";
              "media.class" = "Audio/Source";
              "audio.position" = [ "MONO" ];
            };
          };
        }
      ];
    };
  };
}

{ self, inputs, ... }: {

  flake.nixosModules.pipewire = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.crosspipe pkgs.easyeffects ];
    security.rtkit.enable = true;
    services.pipewire.wireplumber.extraConfig."99-defaults" = {
      "wireplumber.settings" = {
        "default.configured-audio-sink" = "alsa_output.usb-Generic_USB_Audio-00.HiFi__Speaker__sink";
        "default.configured-audio-source" = "mono-mic";
      };
    };

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
              "node.target" = "alsa_input.usb-Generic_USB_Audio-00.HiFi__Mic__source";
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

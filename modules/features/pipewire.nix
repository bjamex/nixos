{ self, inputs, ... }: {

  flake.nixosModules.pipewire = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.crosspipe pkgs.easyeffects ];
    security.rtkit.enable = true;

    # Pin the USB DAC (headphones/mic) as the preferred default over the GPU's
    # HDMI audio. WirePlumber picks the highest priority.session node that is
    # available; the USB device wins normally (828 > 616), but if it is briefly
    # busy at boot HDMI can get cached as the default. Boosting the USB nodes
    # and demoting HDMI makes the USB DAC the decisive default whenever present.
    # (The old `default.configured-audio-sink` settings key does not exist in
    # WirePlumber — `wpctl settings` reports "not found" — so it was a no-op.)
    services.pipewire.wireplumber.extraConfig."90-usb-audio-default" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa_(output|input)\\.usb-Generic_USB_Audio-00\\..*"; } ];
          actions.update-props."priority.session" = 2000;
        }
        {
          matches = [ { "node.name" = "~alsa_output\\.pci-.*\\.hdmi.*"; } ];
          actions.update-props."priority.session" = 100;
        }
      ];
    };

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # services.pipewire.extraConfig.pipewire."mic-mono" = {
    #   "context.modules" = [
    #     {
    #       name = "libpipewire-module-loopback";
    #       args = {
    #         "node.description" = "Mono Mic";
    #         "capture.props" = {
    #           "node.name" = "mono-mic-capture";
    #           "audio.position" = [ "FL" ];
    #           "node.target" = "alsa_input.usb-Generic_USB_Audio-00.HiFi__Mic__source";
    #         };
    #         "playback.props" = {
    #           "node.name" = "mono-mic";
    #           "media.class" = "Audio/Source";
    #           "audio.position" = [ "MONO" ];
    #         };
    #       };
    #     }
    #   ];
    # };
  };
}

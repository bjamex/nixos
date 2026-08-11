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

    # The WF-1000XM4 only sustains LDAC with both buds in; a single bud falls
    # back to AAC/SBC. WirePlumber picks LDAC whenever it is advertised, so
    # pulling one bud made the headset tear down the A2DP transport
    # ("connection .../sep3/fd0 terminated unexpectedly"), WirePlumber
    # re-negotiated LDAC, and the link flapped every ~60s with a ~10s gap.
    # Dropping ldac from the candidate list pins AAC, so the codec never has
    # to change mid-session.
    services.pipewire.wireplumber.extraConfig."51-bluez-no-ldac" = {
      "monitor.bluez.properties" = {
        "bluez5.codecs" = [ "aac" "sbc_xq" "sbc" ];
        "bluez5.enable-sbc-xq" = true;
      };
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

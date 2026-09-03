{ self, inputs, ... }: {

  flake.nixosModules.pipewire = { pkgs, ... }: {
    environment.systemPackages = [
      pkgs.crosspipe
      pkgs.easyeffects
    ];
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

    # Pin the WF-1000XM4 to AAC. This was originally added believing LDAC
    # caused the single-bud dropouts; that turned out to be wrong (the flapping
    # continued on AAC — see the autoswitch block below for the actual cause).
    # Kept anyway: AAC is a much lower bitrate than LDAC, so the link has more
    # headroom. Drop this block if you want LDAC quality back.
    services.pipewire.wireplumber.extraConfig."51-bluez-no-ldac" = {
      "monitor.bluez.properties" = {
        "bluez5.codecs" = [
          "aac"
          "sbc_xq"
          "sbc"
        ];
        "bluez5.enable-sbc-xq" = true;
      };
    };

    # The real cause of the XM4 dropouts. WirePlumber defaults
    # bluetooth.autoswitch-to-headset-profile to true, so any app opening a
    # recording stream flips the buds from A2DP to HFP, which tears down the
    # A2DP transport. The logs show the two events landing in the same second:
    #   bluetoothd: ext_io_disconnected() Unable to get io data for
    #               Hands-Free Voice gateway: ... not connected (107)
    #   wireplumber: connection (.../sep2/fd0) terminated unexpectedly
    # styx has a dedicated USB mic as its default source, so the earbud mic is
    # never wanted — keep the buds in A2DP unconditionally.
    services.pipewire.wireplumber.extraConfig."52-bluez-no-headset-autoswitch" = {
      "wireplumber.settings" = {
        "bluetooth.autoswitch-to-headset-profile" = false;
      };
    };

    # The onboard Realtek codec never enumerates. The PCH HDA controller itself
    # binds fine (00:1f.3, snd_hda_intel, "Onboard - Sound"), but the boot log
    # ends at "no codecs found!" and /sys/bus/hdaudio/devices/ holds only the
    # GPU's HDMI codec — so the board's analog jacks do not exist as far as ALSA
    # is concerned. That leaves the Generic USB Audio device as the only analog
    # input, and its mic stage tops out at +12 dB, which is not enough for the
    # NTH-Mic: capture sits pinned at ALSA 39/39 *and* 150% in PipeWire and is
    # still quiet. A Realtek codec would offer +20-30 dB of Mic Boost instead.
    # probe_mask=1 forces a probe of codec slot 0 rather than trusting the
    # controller's (empty) codec bitmap. A no-op if the codec is truly absent.
    #
    # Tested 2026-09-03 on kernel 7.2.2 (up from 7.1.8): no change. The option
    # reaches /etc/modprobe.d/ but the boot log still ends at "no codecs
    # found!" for 00:1f.3, card 1 exposes no codec, and /sys/bus/hdaudio/
    # still holds only hdaudioC2D0 (the ATI HDMI codec). So the Realtek is
    # genuinely absent rather than mis-enumerated — firmware/BIOS territory,
    # not the driver. Kept as a record of what has already been ruled out.
    boot.extraModprobeConfig = ''
      options snd-hda-intel probe_mask=1
    '';

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

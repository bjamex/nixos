{ self, inputs, ... }: {
  flake.nixosModules.beammp = { pkgs, ... }:
  let
    # BeamMP multiplayer launcher for BeamNG.drive. The upstream launcher
    # self-updates and dlopen()s a pile of runtime libs, so run it inside an
    # FHS env that provides them. See r/BeamMP native NixOS module thread.
    beammpIcon = pkgs.fetchurl {
      url = "https://beammp.com/assets/BeamMP_blk-BycyukAv.png";
      sha256 = "sha256-7osWdvH3vG6Jf2I9U0/OPPVSL8wDlTIenwytng5xOyM=";
    };

    beammp-launcher = pkgs.buildFHSEnv {
      name = "BeamMP-Launcher";
      targetPkgs = p: with p; [
        nspr
        libuuid
        fontconfig
        freetype
        glib
        nss
        dbus
        at-spi2-atk
        cups
        libx11
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxrandr
        libxcb
        libxkbcommon
        cairo
        pango
        udev
        alsa-lib
        libgbm

        # The launcher posix_spawn()s BeamNG itself, so the game runs inside
        # this same FHS and its deps have to be here too: wayland for the
        # native Linux build's window backend, expat for libcef.
        wayland
        expat
        gtk3 # only for BinLinux/crashReporter

        libGL
        libGLU
        vulkan-loader
        vulkan-tools
        libvdpau
        libva
      ];
      runScript = "${pkgs.beammp-launcher}/bin/BeamMP-Launcher";
    };

    beammpDesktopItem = pkgs.makeDesktopItem {
      name = "BeamMP-Launcher";
      desktopName = "BeamMP";
      comment = "BeamNG.drive Multiplayer";
      exec = "${beammp-launcher}/bin/BeamMP-Launcher";
      icon = "${beammpIcon}";
      categories = [ "Game" ];
      terminal = true;
    };
  in
  {
    environment.systemPackages = [ beammp-launcher beammpDesktopItem ];
  };
}

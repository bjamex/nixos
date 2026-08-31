# Shared desktop foundation for styx and void — everything both hosts set
# identically lives here so a package/setting added for "my machines" is a
# one-place edit. Host files keep only genuine differences (monitors, mounts,
# host-only services/packages). hades does NOT import this (headless server).
{ self, inputs, ... }:
{
  flake.nixosModules.common =
    { pkgs, ... }:
    {
      imports = [
        # Cisco Packet Tracer 9 — needs the NetAcad .deb added by hand, see module
        self.nixosModules.packetTracer
        self.nixosModules.wayscriber # screen annotation overlay (SUPER+ALT binds)
        self.nixosModules.nixCore # nix daemon policy shared with hades
      ];

      # --- Nix ---
      nixpkgs.overlays = [
        (final: prev: {
          # pkgs.stable pinned escape hatch for packages unstable breaks
          # (currently lutris and freecad — see gaming.nix / package lists).
          stable = import inputs.nixpkgs-pinned {
            system = final.stdenv.hostPlatform.system;
            config.allowUnfree = true;
          };
        })
      ];

      # --- Boot ---
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.kernelPackages = pkgs.linuxPackages_latest;

      # --- Networking ---
      networking.networkmanager.enable = true;
      networking.firewall.enable = true;
      # Desktops are reachable in person + over Tailscale; no SSH daemon.
      services.openssh.enable = false;

      # --- Locale & Time ---
      time.timeZone = "Australia/Brisbane";
      i18n.defaultLocale = "en_AU.UTF-8";

      # --- Bluetooth ---
      hardware.bluetooth.enable = true;
      hardware.bluetooth.powerOnBoot = true;
      services.blueman.enable = true;

      # --- Scanning & Printing ---
      hardware.sane.enable = true;
      services.printing.enable = true;
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      # --- Shell ---
      # `n` = quick nvim launch (Neovim/LazyVim, see neovim.nix).
      programs.bash.shellAliases.n = "nvim";

      # --- Programs ---
      security.polkit.enable = true;
      programs.appimage = {
        enable = true;
        binfmt = true;
      };

      # --- Virtualisation ---
      virtualisation.docker.enable = true;

      # --- Services ---
      services.flatpak.enable = true;

      # --- Users ---
      users.users.swin = {
        isNormalUser = true;
        description = "Brett James";
        # Hosts append host-specific groups (e.g. styx: input, ratbagd);
        # extraGroups definitions merge across modules.
        extraGroups = [
          "networkmanager"
          "wheel"
          "render"
          "video"
          "docker"
          "scanner"
          "lp"
          "dialout"
        ];
      };

      # --- Packages ---
      environment.systemPackages = with pkgs; [
        # Shell utilities
        (writeShellScriptBin "nwhich" "readlink -f $(which $1)")
        (writeShellScriptBin "cnwhich" "cat $(readlink -f $(which $1))")
        (writeShellScriptBin "md" "mkdir -p \"$1\" && cd \"$1\"")

        # Development
        git
        gh
        claude-code
        nh
        bruno

        # Terminal & System
        btop
        ncdu
        baobab
        qdirstat
        fzf
        lazygit
        weathr

        # Internet & Communication
        inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.helium
        qbittorrent
        nordpass
        localsend

        # Media & Creative
        ffmpeg # audio/video transcode; also lets open-webui do voice/audio
        rapidraw
        obs-studio
        darktable
        jellyfin-tui
        cliamp
        yt-dlp # cliamp shells out to this for YouTube Music playback
        ani-cli
        loupe
        vlc
        inkscape
        pinta
        xournalpp

        # Productivity
        impression
        libreoffice
        gnome-calculator
        pdfarranger
        stable.freecad # unstable's freecad→vtk→pdal breaks on the 2026-07 GDAL bump

        # Networking & Monitoring
        nethogs
        linssid
        moonlight-qt
        pamixer
        cifs-utils
      ];

      # --- Browser ---
      xdg.mime.defaultApplications = {
        "text/html" = "helium.desktop";
        "x-scheme-handler/http" = "helium.desktop";
        "x-scheme-handler/https" = "helium.desktop";
        "x-scheme-handler/about" = "helium.desktop";
        "x-scheme-handler/unknown" = "helium.desktop";
      };
      environment.sessionVariables.BROWSER = "helium";
    };
}

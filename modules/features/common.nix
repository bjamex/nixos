# Shared desktop foundation for styx and void — everything both hosts set
# identically lives here so a package/setting added for "my machines" is a
# one-place edit. Host files keep only genuine differences (monitors, mounts,
# host-only services/packages). hades does NOT import this (headless server).
{ self, inputs, ... }:
{
  flake.nixosModules.common =
    { pkgs, lib, ... }:
    {
      imports = [
        self.nixosModules.wayscriber # screen annotation overlay (SUPER+ALT binds)
        self.nixosModules.nixCore # nix daemon policy shared with hades
        self.nixosModules.fonts # fonts.packages + fontconfig defaults (incl. Calibri)
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
      networking.networkmanager.dns = "systemd-resolved";
      networking.firewall.enable = true;
      services.resolved.enable = true;
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
      }
      # --- Media ---
      # With no default set, whichever installed app claims a type wins — so
      # adding kdenlive silently made it the opener for mp4/mkv/webm/mp3. Pin
      # VLC for every video/audio type kdenlive claims, plus the other common
      # ones (all checked against vlc.desktop's MimeType list).
      // lib.genAttrs [
        # the 14 kdenlive claims
        "video/mp4"
        "video/x-matroska"
        "video/webm"
        "video/quicktime"
        "video/x-msvideo"
        "video/mpeg"
        "video/3gpp"
        "video/3gpp2"
        "audio/mpeg"
        "audio/mp4"
        "audio/flac"
        "audio/ogg"
        "audio/wav"
        "audio/x-matroska"
        # other common formats
        "video/x-m4v"
        "video/x-flv"
        "video/x-ms-wmv"
        "video/ogg"
        "video/mp2t"
        "video/x-ogm+ogg"
        "video/avi"
        "audio/aac"
        "audio/x-aac"
        "audio/opus"
        "audio/x-flac"
        "audio/x-vorbis+ogg"
        "audio/x-wav"
        "audio/x-ms-wma"
        "audio/x-m4a"
        "audio/mp3"
        "audio/x-mp3"
      ] (_: "vlc.desktop");
      environment.sessionVariables.BROWSER = "helium";
    };
}

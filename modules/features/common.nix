# Shared desktop foundation for styx and void — every module and setting both
# hosts use lives here, so adding something to "my machines" is a one-place
# edit. Host files keep only genuine differences (monitors, mounts, host-only
# services/packages). hades does NOT import this (headless server).
{ self, inputs, ... }:
{
  flake.nixosModules.common =
    { pkgs, lib, ... }:
    {
      imports = [
        inputs.lix-module.nixosModules.lixFromNixpkgs
        self.nixosModules.nixCore # nix daemon policy (shared with hades)
        self.nixosModules.swinHome # hjem dotfiles for swin

        # Desktop session
        self.nixosModules.login
        self.nixosModules.hyprland
        self.nixosModules.webapps # URLs as launcher entries (see myWebApps)
        self.nixosModules.wayscriber # screen annotation overlay (mod+ALT binds)
        self.nixosModules.fonts
        self.nixosModules.pipewire
        self.nixosModules.fileManager

        # Terminal & editor
        self.nixosModules.kitty
        self.nixosModules.shell
        self.nixosModules.neovim
        self.nixosModules.herdr

        # Network & sync
        self.nixosModules.tailscale
        self.nixosModules.smb
        self.nixosModules.insync

        # Apps
        self.nixosModules.gaming
        self.nixosModules.thunderbird
        self.nixosModules.davinciResolve
        self.nixosModules.bambuStudio
        self.nixosModules.omaphoto
        self.nixosModules.lightcraft
        self.nixosModules.craftApps # the rest of the ArtCraft suite
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

          # Opus 5.5 needs the client at >= 2.1.280; nixpkgs is on 2.1.278.
          # Upstream ships a prebuilt binary, so this is just a version+hash
          # bump. DROP THIS once nixpkgs passes 2.1.280 — check with
          #   nix eval nixpkgs#claude-code.version
          claude-code = prev.claude-code.overrideAttrs (_: rec {
            version = "2.1.280";
            src = prev.fetchurl {
              url = "https://downloads.claude.ai/claude-code-releases/${version}/linux-x64/claude.zst";
              hash = "sha256-J5EOKucE2PLoAkiX2P3x53EIB7r09pgsDjeXwFgxU4Q=";
            };
          });
        })
      ];

      # --- Boot ---
      boot = {
        loader.systemd-boot.enable = true;
        loader.efi.canTouchEfiVariables = true;
        kernelPackages = pkgs.linuxPackages_latest;
      };

      # --- Networking ---
      networking = {
        networkmanager.enable = true;
        networkmanager.dns = "systemd-resolved";
        firewall.enable = true;
      };
      services.resolved.enable = true;
      # Desktops are reachable in person + over Tailscale; no SSH daemon.
      services.openssh.enable = false;

      # --- Locale & Time ---
      time.timeZone = "Australia/Brisbane";
      i18n.defaultLocale = "en_AU.UTF-8";

      # --- Bluetooth ---
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };
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

      # --- Default apps ---
      # Helium for web links. For media: with no default set, whichever
      # installed app claims a type wins — so adding kdenlive silently made it
      # the opener for mp4/mkv/webm/mp3. Pin VLC for every video/audio type
      # kdenlive claims, plus the other common ones (all checked against
      # vlc.desktop's MimeType list).
      environment.sessionVariables.BROWSER = "helium";
      xdg.mime.defaultApplications =
        lib.genAttrs [
          "text/html"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
          "x-scheme-handler/about"
          "x-scheme-handler/unknown"
        ] (_: "helium.desktop")
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
    };
}

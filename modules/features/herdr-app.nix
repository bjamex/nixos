# Herdr desktop app (github.com/herdrdev/herdr-app): a GPU window for the same
# agent-aware terminals as the herdr TUI (herdr.nix), with spaces, an agents
# sidebar and SSH machines. It's a separate stack from the TUI: the window
# drives herdr-core, a background runtime that owns the terminals, so closing
# the window leaves them running.
#
# Neither repo ships a flake or a nixpkgs package, and herdr-app vendors
# ghostty plus a GPUI fork, so both come from upstream's release tarballs
# (the URLs and checksums in releases.herdr.dev/{app,core}/latest.json).
# herdr-core is a static binary and runs as-is; herdr-app gets autoPatchelf
# and an LD_LIBRARY_PATH wrapper for the libraries it dlopen()s, like
# craft-apps.nix.
#
# The release build updates itself only when herdr-app.svg sits beside the
# binary, so the icon goes to share/icons and the app never tries to write
# into the store. It also sends usage telemetry by default; the wrapper turns
# that off with HERDR_TELEMETRY=0.
#
# To update: bump a version, then convert the new sha256 from latest.json with
# `nix hash to-sri --type sha256 <hex>`. Keep core at or above the app's
# `core_min` there.
{ ... }:
{
  flake.nixosModules.herdrApp =
    { pkgs, lib, ... }:
    let
      herdr-core = pkgs.stdenvNoCC.mkDerivation rec {
        pname = "herdr-core";
        version = "0.1.21";
        src = pkgs.fetchurl {
          url = "https://releases.herdr.dev/core/${version}/herdr-core-linux-x86_64.tar.gz";
          hash = "sha256-eEJHVcEKQN3jigvbVcIKwZcG6a4F7Wj8Ks8fz/DZQcE=";
        };
        sourceRoot = ".";
        installPhase = ''
          runHook preInstall
          install -Dm755 herdr-core $out/bin/herdr-core
          # Upstream's installer adds `hc` as the short name; the app looks
          # for either.
          ln -s herdr-core $out/bin/hc
          runHook postInstall
        '';
        meta.mainProgram = "herdr-core";
      };

      # Opened at run time with dlopen(): Vulkan (finds the drivers in
      # /run/opengl-driver), EGL, Wayland and xkbcommon-x11.
      runtimeLibs = with pkgs; [
        libglvnd
        libxkbcommon
        vulkan-loader
        wayland
      ];

      herdr-app = pkgs.stdenv.mkDerivation rec {
        pname = "herdr-app";
        version = "0.1.16";
        src = pkgs.fetchurl {
          url = "https://releases.herdr.dev/app/${version}/herdr-app-linux-x86_64.tar.gz";
          hash = "sha256-KC0mMhlrI4IGz+Zr+2HA+vKZyhyRhDvQdlIbvjZXEhY=";
        };

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
          makeWrapper
          copyDesktopItems
        ];
        buildInputs = with pkgs; [
          stdenv.cc.cc.lib
          libxcb
          libxkbcommon
        ];

        desktopItems = [
          (pkgs.makeDesktopItem {
            name = "herdr-app";
            desktopName = "Herdr";
            comment = "Terminals and coding agents";
            exec = "herdr-app";
            icon = "herdr-app";
            categories = [
              "Development"
              "TerminalEmulator"
            ];
            startupWMClass = "herdr-app";
          })
        ];

        installPhase = ''
          runHook preInstall
          install -Dm755 herdr-app $out/bin/herdr-app
          install -Dm644 herdr-app.svg $out/share/icons/hicolor/scalable/apps/herdr-app.svg
          runHook postInstall
        '';

        postFixup = ''
          wrapProgram $out/bin/herdr-app \
            --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
            --prefix PATH : "${lib.makeBinPath [ herdr-core ]}" \
            --set-default HERDR_TELEMETRY 0
        '';

        meta.mainProgram = "herdr-app";
      };
    in
    {
      environment.systemPackages = [
        herdr-app
        herdr-core
      ];
    };
}

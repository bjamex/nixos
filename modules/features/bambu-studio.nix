# Bambu Studio — Bambu Lab's slicer, packaged from the upstream Linux AppImage
# (same pattern as rapidraw.nix / bblauncher.nix). nixpkgs' bambu-studio is
# marked unfree (bundled network plugin) so Hydra never builds it — installing
# it from nixpkgs means compiling the whole Slic3r fork locally. The AppImage
# is prebuilt and is what upstream actually tests.
#
# To update to a new release:
# 1. Check the release assets: the AppImage filename embeds a build timestamp
#    (BambuStudio_ubuntu24.04-v<version>-<timestamp>.AppImage) — copy both the
#    `version` and `buildStamp` from the asset name
# 2. Set `hash` to lib.fakeHash
# 3. nixos-rebuild build --flake .#styx
# 4. Copy the "got: sha256-..." from the error into `hash`
# 5. Build again

{ self, ... }:
{
  flake.nixosModules.bambuStudio =
    { pkgs, lib, ... }:
    let
      pname = "bambu-studio";
      version = "02.07.01.62";
      buildStamp = "20260616195227";

      src = pkgs.fetchurl {
        url = "https://github.com/bambulab/BambuStudio/releases/download/v${version}/BambuStudio_ubuntu24.04-v${version}-${buildStamp}.AppImage";
        hash = "sha256-+pi2CFMt+7uysJMUg6rEHlf7GcF1osx719Uo1eD7soc=";
      };

      # Pull the bundled .desktop entry and icon out of the AppImage so it shows
      # up in the launcher instead of being an anonymous binary.
      appimageContents = pkgs.appimageTools.extractType2 { inherit pname version src; };

      bambuStudio = pkgs.appimageTools.wrapType2 {
        inherit pname version src;
        # The AppImage expects webkit2gtk on the host for the login/network
        # pages (it isn't bundled); without it the app runs but Bambu account
        # login and the device page render blank. glib-networking is webkit's
        # TLS backend (a GIO module) — without it the webview shows
        # "TLS support is not available" on every https page.
        extraPkgs = p: [
          p.webkitgtk_4_1
          p.glib-networking
        ];
        extraBwrapArgs = [
          # The app probes Fedora's CA path (/etc/pki/tls/certs/ca-bundle.crt)
          # and pops an SSL warning on every launch when it's absent; point it
          # at NixOS's bundle instead, as the dialog itself suggests.
          "--setenv"
          "SSL_CERT_FILE"
          "/etc/ssl/certs/ca-certificates.crt"
          # nixpkgs glib only searches its own store path for GIO modules, so
          # glib-networking must be announced explicitly.
          "--setenv"
          "GIO_EXTRA_MODULES"
          "${pkgs.glib-networking}/lib/gio/modules"
        ];
        extraInstallCommands = ''
          install -Dm444 ${appimageContents}/BambuStudio.desktop \
            $out/share/applications/${pname}.desktop
          substituteInPlace $out/share/applications/${pname}.desktop \
            --replace-fail 'Exec=AppRun' 'Exec=${pname}' \
            --replace-fail 'Icon=BambuStudio' 'Icon=${pname}'
          install -Dm444 ${appimageContents}/BambuStudio.png \
            $out/share/icons/hicolor/256x256/apps/${pname}.png
        '';
      };
    in
    {
      environment.systemPackages = [ bambuStudio ];
    };
}

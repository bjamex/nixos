# Scalpel — a fourth-party Path of Exile 1/2 overlay & price checker, packaged as an
# alternative to Exiled Exchange 2 (see exiled-exchange.nix).
#
# Packaged from the prebuilt AppImage. Unlike EE2's AppImage, Scalpel's own build patches the
# uiohook-napi XkbGetKeyboard bug (scripts/postinstall.js applies a patch-package fix and
# rebuilds uiohook from source) BEFORE the AppImage is assembled in CI — so the bundled uiohook
# already works under Hyprland's XWayland, which is exactly what broke EE2's AppImage.
#
# Scalpel pins Electron 32.3.3 (no longer in nixpkgs); the AppImage bundles its own Electron,
# so we don't touch Electron at all.
#
# To update to a new version:
# 1. Bump `version` below (the asset filename is unversioned: Scalpel.AppImage)
# 2. Set `hash` to lib.fakeHash
# 3. nixos-rebuild build --flake .#styx
# 4. Copy the "got: sha256-..." from the error into `hash`
# 5. Build again

{ self, ... }:
{
  flake.nixosModules.scalpel =
    { pkgs, lib, ... }:
    let
      pname = "scalpel";
      version = "0.9.12";

      src = pkgs.fetchurl {
        url = "https://github.com/scalpelpoe/scalpel/releases/download/v${version}/Scalpel.AppImage";
        hash = "sha256-f1pO0cyherYldxeLnSuMeIua3TjbZTSyrMo+QZPyEtE=";
      };

      base = pkgs.appimageTools.wrapType2 {
        inherit pname version src;
        # bwrap submounts don't propagate — bind the drives so Scalpel can read the PoE2 client
        # log (Client.txt) for league/game detection. Mirrors EE2's old AppImage packaging.
        extraBwrapArgs = [
          "--bind-try"
          "/mnt/nvme0"
          "/mnt/nvme0"
          "--bind-try"
          "/mnt/nvme2"
          "/mnt/nvme2"
          "--bind-try"
          "/mnt/nvme3"
          "/mnt/nvme3"
        ];
      };

      scalpel = pkgs.symlinkJoin {
        name = pname;
        paths = [ base ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        # Force --ozone-platform=x11 on EVERY launch path (desktop, keybind, terminal). With the
        # global NIXOS_OZONE_WL=1, a bare launch would otherwise default to native Wayland, which
        # breaks uiohook's global hotkey capture (the EE2 lesson).
        postBuild = ''
          wrapProgram $out/bin/${pname} --add-flags "--ozone-platform=x11"

          mkdir -p $out/share/applications
          cat > $out/share/applications/${pname}.desktop << 'EOF'
          [Desktop Entry]
          Name=Scalpel
          Comment=Path of Exile fourth-party overlay / price checker
          Exec=${pname}
          Icon=${pname}
          Type=Application
          Categories=Game;Utility;
          StartupWMClass=Scalpel
          EOF
        '';
      };
    in
    {
      environment.systemPackages = [ scalpel ];
    };
}

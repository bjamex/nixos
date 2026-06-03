{ self, inputs, ... }: {
  flake.nixosModules.exiledExchange = { pkgs, ... }:
  let
    src = pkgs.fetchurl {
      url = "https://github.com/Kvan7/Exiled-Exchange-2/releases/download/v0.15.2/exiled-exchange-2-0.15.2.AppImage";
      hash = "sha256-LNXiVZvPIrPbrmpiS4g+iBGi0+Jn2lott8fsy+uJnfw=";
    };

    extracted = pkgs.appimageTools.extract {
      pname = "exiled-exchange-2";
      version = "0.15.2";
      inherit src;
    };

    desktopFile = pkgs.writeText "exiled-exchange-2.desktop" ''
      [Desktop Entry]
      Name=Exiled Exchange 2
      Exec=exiled-exchange-2
      Terminal=false
      Type=Application
      Icon=exiled-exchange-2
      StartupWMClass=Exiled Exchange 2
      Categories=Utility;
    '';

    # Patch clipboard poller: Kc=48 (poll interval ms) → Kc=75, yk=500 (timeout ms) → yk=1e3.
    # Same-length binary replacements preserve asar offset table integrity.
    # yk=1e3 = 1000ms — slight buffer over default 500ms for Wine/Proton→X11 clipboard sync.
    patched = pkgs.runCommand "exiled-exchange-2-0.15.2-patched" {
      nativeBuildInputs = [ pkgs.python3 ];
    } ''
      cp -r ${extracted} $out
      chmod -R u+w $out
      python3 -c "
import sys
asar = sys.argv[1]
d = open(asar, 'rb').read()
d = d.replace(b'Kc=48', b'Kc=75')
d = d.replace(b'yk=500', b'yk=1e3')
open(asar, 'wb').write(d)
" $out/resources/app.asar
    '';

    appimage = pkgs.appimageTools.wrapAppImage {
      pname = "exiled-exchange-2";
      version = "0.15.2";
      src = patched;
      # Mount nvme drives — bubblewrap's --bind /mnt /mnt does not propagate submounts
      extraBwrapArgs = [
        "--bind" "/mnt/nvme0" "/mnt/nvme0"
        "--bind" "/mnt/nvme2" "/mnt/nvme2"
        "--bind" "/mnt/nvme3" "/mnt/nvme3"
      ];
      extraInstallCommands = ''
        install -Dm644 ${desktopFile} $out/share/applications/exiled-exchange-2.desktop
        install -Dm644 ${extracted}/usr/share/icons/hicolor/256x256/apps/exiled-exchange-2.png \
          $out/share/icons/hicolor/256x256/apps/exiled-exchange-2.png
      '';
    };
  in {
    environment.systemPackages = [
      # Force X11 mode — no native Wayland support yet, XDG_SESSION_TYPE=x11
      # lets global hotkeys and the overlay work via xwayland-satellite
      (pkgs.symlinkJoin {
        name = "exiled-exchange-2";
        paths = [ appimage ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/exiled-exchange-2 \
            --set XDG_SESSION_TYPE x11 \
            --set GDK_BACKEND x11 \
            --set GTK_THEME Adwaita \
            --add-flags "--ozone-platform=x11 --enable-transparent-visuals"
        '';
      })
    ];
  };
}

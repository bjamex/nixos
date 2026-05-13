{ self, inputs, ... }: {
  flake.nixosModules.exiledExchange = { pkgs, ... }:
  let
    appimage = pkgs.appimageTools.wrapType2 {
      pname = "exiled-exchange-2";
      version = "0.13.10";
      src = pkgs.fetchurl {
        url = "https://github.com/Kvan7/Exiled-Exchange-2/releases/download/v0.13.10/exiled-exchange-2-0.13.10.AppImage";
        hash = "sha256-mQNUJptaObbEMtBLCgJn7A6nmgVpl4o0JWTg6FH20U0=";
      };
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

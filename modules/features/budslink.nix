{ ... }:
{

  flake.nixosModules.budslink =
    { pkgs, ... }:
    let
      budslink = pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = "budslink";
        version = "0.1.4";

        src = pkgs.fetchFromGitHub {
          owner = "maniacx";
          repo = "BudsLink";
          rev = "v${finalAttrs.version}";
          hash = "sha256-s87pFrSY8esCYsqZ4M3mPRxoo29qrgFbEYBdk9E/P/A=";
        };

        nativeBuildInputs = with pkgs; [
          meson
          ninja
          pkg-config
          gettext
          gobject-introspection
          wrapGAppsHook4
          gjs
          desktop-file-utils
        ];

        buildInputs = with pkgs; [
          gjs
          gtk4
          libadwaita
          glib
          pulseaudio
        ];

        postPatch = ''
          substituteInPlace src/app.js \
            --replace-fail 'GLibUnix.signal_add(' 'GLibUnix.signal_add_full('
        '';
      });
    in
    {
      environment.systemPackages = [ budslink ];
    };
}

{ ... }: {

  # RapidRAW lags in nixpkgs, so we pull it straight from upstream's GitHub
  # release AppImage instead. Bumping = change `version` + `hash`, rebuild.
  #   nix-prefetch-url <url> | xargs nix hash to-sri --type sha256
  flake.nixosModules.rapidraw = { ... }: {
    nixpkgs.overlays = [
      (final: prev: {
        rapidraw =
          let
            version = "1.5.7";
          in
          final.appimageTools.wrapType2 {
            pname = "rapidraw";
            inherit version;
            src = final.fetchurl {
              url = "https://github.com/CyberTimon/RapidRAW/releases/download/v${version}/03_RapidRAW_v${version}_ubuntu-24.04_amd64.AppImage";
              hash = "sha256-FRZoCMoHNNgxwXwpJ6QLvv1Nj1Q7OejImKnkHA72B4I=";
            };
          };
      })
    ];
  };
}

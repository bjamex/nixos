# BB_Launcher — a dedicated launcher / mod manager for Bloodborne on shadPS4
# (rainmakerv3/BB_Launcher). It sits on top of the shadps4 core (see gaming.nix)
# and applies Bloodborne mods/patches: 60fps unlock, FOV, HD textures, a save
# editor, and a mod merger. Point it at the shadps4 binary and your Bloodborne
# install from its settings screen.
#
# Packaged from the upstream Linux AppImage (same pattern as scalpel.nix /
# rapidraw.nix). The AppImage bundles its own Qt, so we don't touch Qt here.
#
# To update to a new release:
# 1. Bump `version` below (matches the `ReleaseNN.NN` git tag)
# 2. Set `hash` to lib.fakeHash
# 3. nixos-rebuild build --flake .#styx
# 4. Copy the "got: sha256-..." from the error into `hash`
# 5. Build again

{ self, ... }:
{
  flake.nixosModules.bblauncher =
    { pkgs, lib, ... }:
    let
      pname = "bb-launcher";
      version = "16.05";

      src = pkgs.fetchurl {
        url = "https://github.com/rainmakerv3/BB_Launcher/releases/download/Release${version}/BB_Launcher-qt.AppImage";
        hash = "sha256-RjGFwWIS29VjCAqsrnKdldV+37MAaED3EEF+7ujrxMM=";
      };

      # Pull the bundled .desktop entry and icon out of the AppImage so it shows
      # up in the launcher instead of being an anonymous binary.
      appimageContents = pkgs.appimageTools.extractType2 { inherit pname version src; };

      bblauncher = pkgs.appimageTools.wrapType2 {
        inherit pname version src;
        extraInstallCommands = ''
          install -Dm444 ${appimageContents}/BBLauncher.desktop \
            $out/share/applications/${pname}.desktop
          substituteInPlace $out/share/applications/${pname}.desktop \
            --replace-fail 'Exec=BB_Launcher' 'Exec=${pname}' \
            --replace-fail 'Icon=BBIcon' 'Icon=${pname}'
          install -Dm444 ${appimageContents}/usr/share/icons/hicolor/256x256/apps/BBIcon.png \
            $out/share/icons/hicolor/256x256/apps/${pname}.png
        '';
      };
    in
    {
      environment.systemPackages = [ bblauncher ];
    };
}

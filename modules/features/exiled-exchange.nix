# Built from source so uiohook-napi links against the SYSTEM X11 libs (libxtst/libx11/
# libxi/...) via LD_LIBRARY_PATH. The upstream AppImage bundles its own X11 libs that are
# incompatible with Hyprland's XWayland — uiohook then fails ("XkbGetKeyboard failed to
# locate a valid keyboard") and the price-check hotkeys barely register (need holding for
# seconds). Mirrors awakened-poe-trade.nix.
#
# To update to a new version:
# 1. nix run nixpkgs#nix-prefetch-github -- Kvan7 Exiled-Exchange-2 --rev <tag>
# 2. Update rev, hash, version below
# 3. Set outputHash to lib.fakeHash
# 4. nixos-rebuild build --flake .#styx
# 5. Copy the "got: sha256-..." from the error into outputHash
# 6. Build again

{ self, inputs, ... }:
{
  flake.nixosModules.exiledExchange =
    { pkgs, lib, ... }:
    let
      pname = "exiled-exchange-2";
      version = "0.15.4";
      electron = pkgs.electron_40;

      src = pkgs.fetchFromGitHub {
        owner = "Kvan7";
        repo = "Exiled-Exchange-2";
        rev = "v0.15.4";
        hash = "sha256-c0598C7VzXWa7uYr1aw8h4+tTQI0sGJBdUeTqPPdtYk=";
      };

      builtApp = pkgs.stdenv.mkDerivation {
        pname = "${pname}-built";
        inherit version src;

        nativeBuildInputs = with pkgs; [
          nodejs
          cacert
          jq
        ];

        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        outputHash = "sha256-4WZ5/sgOkBRgGgaFOGlUeRY1JV6sMxN3hsa9mOZza+g=";

        # Pure download content: don't let fixupPhase shrink RPATHs of the
        # prebuilt *.node binaries, which would bake /nix/store refs into the
        # FOD (forbidden). Runtime libs come from the wrapper's LD_LIBRARY_PATH.
        dontFixup = true;

        buildPhase = ''
          export HOME=$TMPDIR
          export npm_config_cache=$TMPDIR/.npm
          cd renderer
          npm ci
          patchShebangs node_modules
          npm run make-index-files
          npm run build
          cd ..
          # Force uiohook-napi 1.5.5: the upstream lock pins 1.5.4, whose
          # XkbGetKeyboard call is rejected by current XWayland (breaks the
          # price-check hotkey + synthetic copy). 1.5.5 drops that call. Drop
          # main's lock so the new pin resolves on install.
          jq '.dependencies."uiohook-napi" = "1.5.5" | .overrides."uiohook-napi" = "1.5.5"' \
            main/package.json > main/package.json.tmp
          mv main/package.json.tmp main/package.json
          rm -f main/package-lock.json
          cd main
          npm install --ignore-scripts
          patchShebangs node_modules
          echo "${electron}/bin/electron" > node_modules/electron/path.txt
          npm run build
          cd ..
        '';

        installPhase = ''
          mkdir -p $out
          cp main/dist/main.js $out/
          cp main/dist/vision.js $out/
          cp -r renderer/dist $out/renderer
          cd main
          rm -rf node_modules
          npm install --omit=dev --ignore-scripts
          cp -r node_modules $out/node_modules
          rm -rf $out/node_modules/.bin
          cd ..
        '';
      };

      exiledExchange2 = pkgs.stdenv.mkDerivation {
        inherit pname version;

        dontUnpack = true;
        dontConfigure = true;
        dontBuild = true;

        nativeBuildInputs = [ pkgs.makeWrapper ];

        installPhase = ''
          runHook preInstall

          mkdir -p $out/share/${pname} $out/share/applications $out/bin

          cp ${builtApp}/main.js $out/share/${pname}/
          cp ${builtApp}/vision.js $out/share/${pname}/
          cp -r ${builtApp}/renderer/* $out/share/${pname}/
          cp -r ${builtApp}/node_modules $out/share/${pname}/

          echo '{"name":"exiled-exchange-2","version":"${version}","main":"main.js"}' \
            > $out/share/${pname}/package.json

          cat > $out/share/applications/${pname}.desktop << 'EOF'
          [Desktop Entry]
          Name=Exiled Exchange 2
          Comment=Path of Exile 2 trading macro
          Exec=exiled-exchange-2
          Icon=exiled-exchange-2
          Type=Application
          Categories=Game;Utility;
          StartupWMClass=Exiled Exchange 2
          EOF

          runHook postInstall
        '';

        postFixup = ''
          makeWrapper ${lib.getExe electron} $out/bin/${pname} \
            --add-flags $out/share/${pname} \
            --add-flags "--ozone-platform=x11 --enable-transparent-visuals" \
            --prefix LD_LIBRARY_PATH : "${
              lib.makeLibraryPath (
                with pkgs;
                [
                  libxtst
                  libxt
                  libxkbcommon
                  libx11
                  libxi
                  libxinerama
                ]
              )
            }"
        '';

        meta = {
          description = "Source-built Exiled Exchange 2 with Hyprland/XWayland hotkey fix";
          homepage = "https://github.com/Kvan7/Exiled-Exchange-2";
          license = lib.licenses.mit;
          platforms = lib.platforms.linux;
          mainProgram = pname;
        };
      };
    in
    {
      environment.systemPackages = [ exiledExchange2 ];
    };
}

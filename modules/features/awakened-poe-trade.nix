# Built from source so uiohook-napi links against the SYSTEM X11 libs via LD_LIBRARY_PATH,
# and force-pinned to uiohook-napi 1.5.5: upstream's main/package-lock.json pins 1.5.4,
# whose XkbGetKeyboard call is rejected by current XWayland (breaks the price-check
# hotkey). The nixpkgs package wraps the AppImage which has the same problem.
# Mirrors exiled-exchange.nix.
#
# To update to a new version:
# 1. nix run nixpkgs#nix-prefetch-github -- SnosMe awakened-poe-trade --rev <tag-commit>
# 2. Update rev, hash, and version below
# 3. Set outputHash to lib.fakeHash
# 4. Run: nixos-rebuild build --flake .#styx
# 5. Copy the "got: sha256-..." from the error into outputHash
# 6. Build again

{ self, inputs, ... }:
{
  flake.nixosModules.awakenedPoeTrade =
    { pkgs, lib, ... }:
    let
      pname = "awakened-poe-trade";
      version = "3.28.103";
      electron = pkgs.electron_41;

      src = pkgs.fetchFromGitHub {
        owner = "SnosMe";
        repo = "awakened-poe-trade";
        rev = "904b2f5e0395c773cd4196e01b0c7f7fcf53f45c";
        hash = "sha256-lJqJNMwLBYO4CYQOGkflJqg0NhYOBHSZeqUYihIU2DU=";
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
        outputHash = "sha256-VkC2cLUw5oC4nWMtBwZDtMfFLxMnVU538t5b1k/ME30="; # uiohook-napi 1.5.5 pin changed the built output

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
          # price-check hotkey). 1.5.5 drops that call. Drop main's lock so
          # the new pin resolves on install.
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

      awakenedPoeTrade = pkgs.stdenv.mkDerivation {
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

          echo '{"name":"awakened-poe-trade","version":"${version}","main":"main.js"}' \
            > $out/share/${pname}/package.json

          cat > $out/share/applications/${pname}.desktop << 'EOF'
          [Desktop Entry]
          Name=Awakened PoE Trade
          Comment=Path of Exile trading macro
          Exec=awakened-poe-trade
          Icon=awakened-poe-trade
          Type=Application
          Categories=Game;Utility;
          StartupWMClass=awakened-poe-trade
          EOF

          runHook postInstall
        '';

        postFixup = ''
          makeWrapper ${lib.getExe electron} $out/bin/${pname} \
            --add-flags $out/share/${pname} \
            --add-flags "--ozone-platform=x11" \
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
          description = "Source-built awakened-poe-trade with Hyprland/XWayland hotkey fix";
          homepage = "https://github.com/SnosMe/awakened-poe-trade";
          license = lib.licenses.mit;
          platforms = lib.platforms.linux;
          mainProgram = pname;
        };
      };
    in
    {
      environment.systemPackages = [ awakenedPoeTrade ];
    };
}

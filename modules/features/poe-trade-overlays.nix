# Awakened PoE Trade (PoE 1) + Exiled Exchange 2 (PoE 2) — the same Electron
# overlay codebase (EE2 is an APT fork), built from source via one shared
# builder so the Electron version and the uiohook-napi pin live in ONE place.
#
# Why source-built at all: the upstream AppImages bundle their own X11 libs
# that are incompatible with Hyprland's XWayland — uiohook then fails
# ("XkbGetKeyboard failed to locate a valid keyboard") and the price-check
# hotkeys barely register. Building from source lets uiohook-napi link against
# the system X11 libs via the wrapper's LD_LIBRARY_PATH, and we force-pin
# uiohook-napi 1.5.5: the upstream locks pin 1.5.4, whose XkbGetKeyboard call
# is rejected by current XWayland; 1.5.5 drops that call.
#
# To update either app to a new version:
# 1. nix run nixpkgs#nix-prefetch-github -- <owner> <repo> --rev <tag/commit>
# 2. Update rev, hash, version in that app's block below
# 3. Set its outputHash to lib.fakeHash
# 4. nixos-rebuild build --flake .#styx
# 5. Copy the "got: sha256-..." from the error into outputHash
# 6. Build again

{ self, inputs, ... }:
let
  mkModule =
    {
      pname,
      version,
      owner,
      repo,
      rev,
      srcHash,
      outputHash,
      desktopName,
      comment,
      wmClass,
      homepage,
      extraElectronFlags ? "",
    }:
    { pkgs, lib, ... }:
    let
      electron = pkgs.electron_41; # was electron_40; 40.x went EOL/insecure 2026-07

      src = pkgs.fetchFromGitHub {
        inherit owner repo rev;
        hash = srcHash;
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
        inherit outputHash;

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
          # Force uiohook-napi 1.5.5 (see file header). Drop main's lock so
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

      app = pkgs.stdenv.mkDerivation {
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

          echo '{"name":"${pname}","version":"${version}","main":"main.js"}' \
            > $out/share/${pname}/package.json

          cat > $out/share/applications/${pname}.desktop << EOF
          [Desktop Entry]
          Name=${desktopName}
          Comment=${comment}
          Exec=${pname}
          Icon=${pname}
          Type=Application
          Categories=Game;Utility;
          StartupWMClass=${wmClass}
          EOF

          runHook postInstall
        '';

        postFixup = ''
          makeWrapper ${lib.getExe electron} $out/bin/${pname} \
            --add-flags $out/share/${pname} \
            --add-flags "--ozone-platform=x11${extraElectronFlags}" \
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
          description = "Source-built ${desktopName} with Hyprland/XWayland hotkey fix";
          inherit homepage;
          license = lib.licenses.mit;
          platforms = lib.platforms.linux;
          mainProgram = pname;
        };
      };
    in
    {
      environment.systemPackages = [ app ];
    };
in
{
  flake.nixosModules.awakenedPoeTrade = mkModule {
    pname = "awakened-poe-trade";
    version = "3.29.101";
    owner = "SnosMe";
    repo = "awakened-poe-trade";
    rev = "6ed02a3c9442e395cc1c93cfd298fd92cec8d3c0";
    srcHash = "sha256-Burc7b9qJDMQMzajoQkQI0KWH4f3J+fTs7BB77cJkZE=";
    outputHash = "sha256-2+U3KM20CPLTiiDMVQF8KuISINkx8adFanzvSFuXHz8="; # rebuilt for 3.29.101
    desktopName = "Awakened PoE Trade";
    comment = "Path of Exile trading macro";
    wmClass = "awakened-poe-trade";
    homepage = "https://github.com/SnosMe/awakened-poe-trade";
  };

  flake.nixosModules.exiledExchange = mkModule {
    pname = "exiled-exchange-2";
    version = "0.15.8";
    owner = "Kvan7";
    repo = "Exiled-Exchange-2";
    rev = "v0.15.8";
    srcHash = "sha256-+ghWAH5fijwOJRC5GssHNnEfHe+RDNUOJmoJ2Ddgt7M=";
    outputHash = "sha256-AU35hEP2Sch3PI00e9HwUJ5r/A/2kucr6pxWK0rX89U="; # rebuilt for the 2026-07-26 nixpkgs bump (toolchain change)
    desktopName = "Exiled Exchange 2";
    comment = "Path of Exile 2 trading macro";
    wmClass = "Exiled Exchange 2";
    homepage = "https://github.com/Kvan7/Exiled-Exchange-2";
    extraElectronFlags = " --enable-transparent-visuals";
  };
}

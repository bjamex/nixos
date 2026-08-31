# StashSage — a fourth-party Path of Exile 2 overlay that does ML-based item
# price prediction (KNN + XGBoost models trained on trade listings). Copy an
# item in-game, hit the hotkey, get a predicted price and comparable listings.
# A third PoE2 price checker alongside Exiled Exchange 2 and Scalpel.
#
# Packaged from upstream's prebuilt Linux zip, which is a PyInstaller "onedir"
# bundle: a StashSage ELF next to an _internal/ tree holding a whole Python
# runtime, ~429 shared objects and the .pkl models. There is no buildable
# source release — the GitHub repo carries only part of the Python and the
# models ship as separate release assets — so this wraps the binary as-is.
#
# Why this one works on Hyprland when EE2's AppImage did not: StashSage is
# Python and takes its global hotkeys from the `keyboard` library, which reads
# /dev/input/event* and writes /dev/uinput. That is evdev-level and therefore
# display-server agnostic — it sidesteps the uiohook XkbGetKeyboard/XWayland
# problem entirely (see poe-trade-overlays.nix for that saga). It does mean
# the app needs input permissions; see the assertion below.
#
# KNOWN COSMETIC ISSUE: on every launch CustomTkinter re-copies its bundled
# fonts into ~/.fonts with shutil.copy, which preserves the source mode. The
# source is the read-only /nix/store, so the copies land 0444 and the next
# copy in the same process hits EACCES:
#   FontManager error: [Errno 13] Permission denied: ~/.fonts/Roboto-Regular.ttf
#   ... Preferred drawing method 'font_shapes' can not be used ...
#   Using 'circle_shapes' instead. The rendering quality will be bad!
# A chmod in the wrapper does NOT fix this — it only makes the first copy of
# each launch succeed, and that copy immediately restores mode 0444 for the
# calls that follow. Fixing it properly needs an upstream patch, so the noise
# is left in place. Impact is limited to how CustomTkinter draws rounded
# widget corners; the app is otherwise fully functional.
#
# SIZE WARNING: ~962 MB download, ~2.8 GB unpacked in the store, and upstream
# ships a release every few days. Each version you build keeps its own copy
# until the next GC.
#
# To update to a new version:
# 1. Bump `version` below
# 2. Set `hash` to lib.fakeHash
# 3. nix build .#nixosConfigurations.styx.config.system.build.toplevel
# 4. Copy the "got: sha256-..." from the error into `hash`
# 5. Build again
{ ... }:
{
  flake.nixosModules.stashsage =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      pname = "stashsage";
      version = "0.5.14";

      src = pkgs.fetchzip {
        url = "https://github.com/rheinze08/StashSage/releases/download/v${version}/StashSageLinux.zip";
        hash = "sha256-DvjwXT8TUy1+sP7aim02BIkm7Z4CLTEMquVW/A1tFPI=";
        # The zip nests everything under a StashSage/ root. Keeping the root
        # (rather than stripRoot = true) is what this hash was computed against;
        # installPhase copies out of the nested dir. Note nix-prefetch-url
        # --unpack strips the root and so reports a DIFFERENT hash than fetchzip
        # gets here — resolve this hash with lib.fakeHash + a build, not prefetch.
        stripRoot = false;
      };

      stashsage = pkgs.stdenv.mkDerivation {
        inherit pname version src;

        nativeBuildInputs = [
          pkgs.autoPatchelfHook
          pkgs.makeWrapper
        ];

        # The bundle vendors its own X11/Tk/fontconfig stack (libX11, libXft,
        # libXss, libtk8.6, libtcl8.6 and both _tcl_data/_tk_data are all inside
        # _internal), so the only external needs are glibc and libxcb.
        buildInputs = [
          pkgs.xorg.libxcb
          pkgs.stdenv.cc.cc.lib
        ];

        # PyInstaller resolves _internal/ relative to the executable, so the
        # tree has to stay intact — install it whole and expose a wrapper on
        # PATH rather than symlinking the binary out of position.
        installPhase = ''
          runHook preInstall

          mkdir -p $out/share/${pname}
          cp -r StashSage/. $out/share/${pname}/
          chmod +x $out/share/${pname}/StashSage

          makeWrapper $out/share/${pname}/StashSage $out/bin/${pname} \
            --prefix PATH : ${
              lib.makeBinPath [
                pkgs.wl-clipboard
                pkgs.xclip
              ]
            }

          runHook postInstall
        '';

        # 429 bundled .so files, most of them already correct — a missing one
        # here is not fatal at patch time and would only surface at runtime.
        dontStrip = true;

        meta = {
          description = "ML-based price prediction overlay for Path of Exile 2";
          homepage = "https://rheinze08.github.io/StashSage/";
          # Upstream ships no LICENSE file, so this is all-rights-reserved by
          # default. We only fetch upstream's own release artifact and never
          # redistribute it, same as the other prebuilt apps in this config.
          license = lib.licenses.unfree;
          platforms = [ "x86_64-linux" ];
          mainProgram = pname;
        };
      };

      desktopItem = pkgs.makeDesktopItem {
        name = pname;
        desktopName = "StashSage";
        genericName = "PoE2 Price Prediction Overlay";
        comment = "ML-based item price prediction for Path of Exile 2";
        exec = pname;
        categories = [
          "Game"
          "Utility"
        ];
        terminal = false;
        startupWMClass = "StashSage";
      };
    in
    {
      environment.systemPackages = [
        stashsage
        desktopItem
      ];

      # StashSage's hotkeys go through the Python `keyboard` library, which
      # READS /dev/input/event* (needs the `input` group) and WRITES
      # /dev/uinput (needs hardware.uinput, which grants the seat owner an
      # ACL on the device). Without both, the app launches fine and the
      # hotkeys silently never fire — so enable uinput here and assert the
      # group, rather than leaving a host to discover it at runtime.
      hardware.uinput.enable = true;

      assertions = [
        {
          assertion = builtins.elem "input" config.users.users.swin.extraGroups;
          message = ''
            stashsage: user "swin" must be in the "input" group — the keyboard
            library reads /dev/input/event* for global hotkeys. Add "input" to
            users.users.swin.extraGroups on this host.
          '';
        }
      ];
    };
}

{ self, inputs, ... }: {
  flake.nixosModules.insync = { pkgs, lib, ... }: {
    boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;
    boot.kernel.sysctl."fs.inotify.max_user_instances" = 512;
    boot.kernel.sysctl."fs.inotify.max_queued_events" = 131072;

    nixpkgs.overlays = [
      (final: prev: {
        insync =
          let
            version = "3.9.10.60041";
            debian-dist = "forky_amd64";
            insync-pkg = prev.stdenvNoCC.mkDerivation {
              pname = "insync-pkg";
              inherit version;
              src = prev.fetchurl {
                url = "https://cdn.insynchq.com/builds/linux/${version}/insync_${version}-${debian-dist}.deb";
                hash = "sha256-wi53iGKLQn3OBD1O4l9Dya7njgFk9Km3Xt7OCW2HOvs=";
              };
              nativeBuildInputs = with prev; [
                dpkg
                autoPatchelfHook
                libsForQt5.qt5.wrapQtAppsHook
              ];
              buildInputs = with prev; [
                alsa-lib
                nss
                lz4
                libgcrypt
                libthai
                libsForQt5.qt5.qtvirtualkeyboard
              ];
              installPhase = ''
                runHook preInstall
                rm -rf usr/lib/insync/PySide2/Qt/qml/
                mkdir -p $out
                cp -R usr/* $out/
                runHook postInstall
              '';
              dontStrip = true;
            };
          in
          prev.buildFHSEnv {
            pname = "insync";
            inherit version;
            targetPkgs = pkgs: with pkgs; [
              libudev0-shim
              insync-pkg
              hicolor-icon-theme
            ];
            extraInstallCommands = ''
              cp -rsHf "${insync-pkg}"/share $out/
            '';
            runScript = prev.writeShellScript "insync-wrapper.sh" ''
              export XKB_CONFIG_ROOT=${prev.xkeyboard_config}/share/X11/xkb/
              exec /usr/lib/insync/insync "$@"
            '';
            unshareUser = false;
            unshareIpc = false;
            unsharePid = false;
            unshareNet = false;
            unshareUts = false;
            unshareCgroup = false;
            dieWithParent = true;
            meta = prev.insync.meta;
          };
      })
    ];

    environment.systemPackages = with pkgs; [
      insync
      insync-nautilus
    ];
  };
}

# Cisco Packet Tracer — the NetAcad network simulator.
#
# Packaged locally rather than taken from nixpkgs (same AppImage-unwrapping
# pattern as bblauncher.nix / bambu-studio.nix). nixpkgs' cisco-packet-tracer_9
# hardcodes 9.0.0 in two places — a `sources` table keyed by version, and the
# literal "CiscoPacketTracer-9.0.0.desktop" in its install phase — and NetAcad
# only publishes the current release, so the pinned version is not the one you
# can actually download. Overriding it needs both a fake `requireFile` and a
# patched install phase; vendoring the (short) derivation is clearer.
#
# The installer cannot be fetched: Cisco puts it behind a NetAcad login, so this
# uses `requireFile` and the build fails until the .deb is in the store by hand:
#
#   1. Sign in at https://www.netacad.com/resources/lab-downloads
#   2. Download CiscoPacketTracer_901_Ubuntu_64bit.deb  (~400 MB)
#   3. nix-store --add-fixed sha256 CiscoPacketTracer_901_Ubuntu_64bit.deb
#
# Keep a copy of the .deb outside the store as well (~/Downloads is fine) —
# step 3 is the whole recovery path, and without a local copy it means logging
# back in to NetAcad. Both desktops need their own copy added; the store is
# per-machine.
#
# To update to a new release: bump `version` and `debVersion`, set `debHash` to
# lib.fakeHash, download the new .deb, add it with step 3, then build and copy
# the "got: sha256-..." into `debHash`.
{ ... }:
{
  flake.nixosModules.packetTracer =
    { pkgs, lib, ... }:
    let
      pname = "cisco-packet-tracer";
      version = "9.0.1";
      debVersion = "901"; # the .deb filename compresses the version: 9.0.1 -> 901

      debHash = "sha256-NoPdh+d5iFNyrpo1wabllNEvST5knnxpdAhynBRZR5s=";

      deb = pkgs.requireFile {
        name = "CiscoPacketTracer_${debVersion}_Ubuntu_64bit.deb";
        hash = debHash;
        url = "https://www.netacad.com/resources/lab-downloads";
      };

      # The .deb is just a carrier — its only payload is the AppImage.
      appimage = pkgs.stdenvNoCC.mkDerivation {
        pname = "${pname}-appimage";
        inherit version;
        src = deb;
        nativeBuildInputs = [ pkgs.dpkg ];
        installPhase = ''
          runHook preInstall
          cp opt/pt/packettracer.AppImage $out
          runHook postInstall
        '';
      };

      contents = pkgs.appimageTools.extract {
        inherit pname version;
        src = appimage;
      };

      packetTracer = pkgs.appimageTools.wrapType2 {
        inherit pname version;
        src = appimage;

        extraPkgs = p: [
          p.libpng
          p.libxkbfile
        ];

        extraBwrapArgs = [
          # The session sets QT_QPA_PLATFORM=wayland globally, but Packet
          # Tracer's bundled Qt has no Wayland platform plugin and aborts with
          # "no Qt platform plugin could be initialized". Force xcb (XWayland)
          # inside the sandbox only, leaving the rest of the session alone.
          "--setenv QT_QPA_PLATFORM xcb"
        ];

        extraInstallCommands = ''
          mv $out/bin/${pname} $out/bin/packettracer9

          install -Dm444 ${contents}/CiscoPacketTracer-${version}.desktop \
            $out/share/applications/cisco-packet-tracer.desktop
          install -Dm444 ${contents}/CiscoPacketTracerPtsa-${version}.desktop \
            $out/share/applications/cisco-packet-tracer-ptsa.desktop
          substituteInPlace $out/share/applications/* \
            --replace-fail "Exec=@EXEC_PATH@" "Exec=packettracer9" \
            --replace-fail "Icon=app" "Icon=${pname}"

          install -Dm444 ${contents}/usr/share/icons/hicolor/48x48/apps/app.png \
            $out/share/icons/hicolor/48x48/apps/${pname}.png
          # Icons for the .pka/.pks/.pkz project mime types.
          cp -r ${contents}/usr/share/icons/gnome/48x48/mimetypes \
            $out/share/icons/hicolor/48x48/

          for desktop in $out/share/applications/*.desktop; do
            sed -i '/^\[Desktop Entry\]/a StartupWMClass=PacketTracer' "$desktop"
          done
        '';

        meta = {
          description = "Network simulation tool from Cisco";
          homepage = "https://www.netacad.com/courses/packet-tracer";
          license = lib.licenses.unfree;
          mainProgram = "packettracer9";
          platforms = [ "x86_64-linux" ];
          sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
        };
      };

      # Context is discarded deliberately: interpolating a derivation into a
      # tmpfiles rule would make the *system closure* depend on it, so a missing
      # .deb would break every rebuild instead of only the ones that actually
      # rebuild Packet Tracer. We only want the path string.
      debPath = builtins.unsafeDiscardStringContext deb.outPath;
    in
    {
      environment.systemPackages = [ packetTracer ];

      # Pin that .deb against the weekly GC (common.nix: --delete-older-than 14d).
      #
      # systemPackages roots the package *output*, not its source, so the
      # installer is collected after 14 days. Nothing breaks right away — it
      # breaks the next time this derivation changes (a version bump here, or an
      # appimageTools/dependency bump on `nix flake update`), when the rebuild
      # has to realise it again, finds the file gone, and dies with requireFile's
      # "please download" message. A permanent gcroot keeps it around instead.
      #
      # The path is derived from `deb` so a version bump moves the root with it
      # rather than silently protecting a stale installer. The symlink is
      # dangling (and harmless) until step 3 above has been done.
      systemd.tmpfiles.rules = [
        "L+ /nix/var/nix/gcroots/cisco-packet-tracer-deb - - - - ${debPath}"
      ];
    };
}

# The ArtCraft "Crafting Apps" (github.com/storytold) — clean-room, pure-Rust
# takes on the Adobe suite: PhotoCraft (Photoshop), VectorCraft (Illustrator),
# FilmCraft (Premiere Pro), EffectCraft (After Effects), DesignCraft (InDesign)
# and PDFCraft (Acrobat). LightCraft (Lightroom) is in lightcraft.nix — it's the
# only one with a flake, so it's source-built from that instead.
#
# None of these are in nixpkgs or ship a flake, so each is unpacked from its
# GitHub release AppImage. Not run through appimageTools.wrapType2: the binaries
# only link libc/libm/libgcc_s and dlopen() the windowing/GPU libs, so it's
# autoPatchelf + an LD_LIBRARY_PATH wrapper — the same thing upstream's own
# LightCraft package.nix does. That skips the bwrap FHS env, and skips the
# AppRun script that copies .desktop files and icons into ~/.local/share.
#
# To update one: bump its `version`, then take the new hash from the release's
# SHA256SUMS.txt (`nix hash to-sri --type sha256 <hex>`), or set lib.fakeHash
# and copy the "got:" from the build error.
{ ... }:
{
  flake.nixosModules.craftApps =
    { pkgs, ... }:
    let
      # Opened at run time with dlopen(): winit loads xkbcommon/wayland/X11,
      # wgpu the Vulkan loader (which finds the drivers in /run/opengl-driver),
      # and rfd libdbus to reach the file-chooser portal — without it every
      # Open/Import dialog silently does nothing (it falls back to zenity).
      runtimeLibs = with pkgs; [
        dbus
        libxkbcommon
        wayland
        libx11
        libxcb
        libxcursor
        libxi
        libxrandr
        vulkan-loader
      ];

      mkCraftApp =
        {
          pname,
          version,
          hash,
        }:
        pkgs.stdenv.mkDerivation {
          inherit pname version;

          src = pkgs.appimageTools.extract {
            inherit pname version;
            src = pkgs.fetchurl {
              url = "https://github.com/storytold/${pname}/releases/download/v${version}/${pname}-${version}-linux-x86_64.AppImage";
              inherit hash;
            };
          };

          nativeBuildInputs = with pkgs; [
            autoPatchelfHook
            makeWrapper
          ];
          # libgcc_s for all; ALSA is linked directly by the apps with audio
          # (EffectCraft, FilmCraft) — autoPatchelf only adds what each needs.
          buildInputs = [
            pkgs.stdenv.cc.cc.lib
            pkgs.alsa-lib
          ];

          # The app plus its `-cli` (headless renderer / MCP server), with the
          # desktop entry, hicolor icons, MIME types and AppStream metadata.
          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -r usr/bin usr/share $out/
            runHook postInstall
          '';

          postFixup = ''
            for bin in $out/bin/*; do
              wrapProgram "$bin" --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeLibs}"
            done
          '';

          meta.mainProgram = pname;
        };
    in
    {
      environment.systemPackages = map mkCraftApp [
        {
          pname = "photocraft";
          version = "0.5.0";
          hash = "sha256-9U2GOAcFO738/6DWJO9+SdP9QTEMe7Ht5IU29pkp0i8=";
        }
        {
          pname = "vectorcraft";
          version = "0.7.0";
          hash = "sha256-9pKPmt9COtChRev+OxQqldPSb1ULBSScIBIUVwH5i2A=";
        }
        {
          pname = "filmcraft";
          version = "0.4.0";
          hash = "sha256-2EEN6nsrBk7eHq2H3YlLyjU3pN/aGkQpcViEn1a6LUw=";
        }
        {
          pname = "effectcraft";
          version = "0.6.0";
          hash = "sha256-jzUuTv4BuOV25ICLljH2igjv/fBdkinCbGoFYcH74Lg=";
        }
        {
          pname = "designcraft";
          version = "0.4.0";
          hash = "sha256-v9J/WeCn6bjUD8ZKpgtv3ZEmmYdiMib3Wa/U18vGT74=";
        }
        {
          pname = "pdfcraft";
          version = "0.4.0";
          hash = "sha256-4hzn3kmRCsyPAypLkGFB2kKzkAI4P7nvM6nYbbvsBdY=";
        }
      ];
    };
}

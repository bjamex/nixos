{ ... }:
{
  # DaVinci Resolve (free edition), bumped to 21.0 ahead of nixpkgs.
  #
  # nixpkgs still ships 20.3.3; the upstream package is a fixed-output
  # derivation that scrapes Blackmagic's download API at build time, so a version
  # bump is just the `version` string plus the two source hashes (free + studio).
  # Rather than vendor the whole 465-line derivation, we substitute those three
  # values into nixpkgs' own package.nix (IFD) — this auto-tracks any other
  # upstream changes to the file.
  #
  # Studio hash is from nixpkgs PR #527765 (davinci-resolve: 20.3.3 -> 21.0);
  # the free hash had to be recomputed because Blackmagic re-rolled the 21.0
  # installer after the PR was opened. Once the PR merges (with a current hash),
  # delete this overlay and the package falls back to nixpkgs.
  flake.nixosModules.davinciResolve =
    { pkgs, ... }:
    let
      # Resolve's bundled Qt5 has no Wayland platform plugin. Our session sets
      # QT_QPA_PLATFORM=wayland globally, so Qt aborts at startup
      # (createPlatformIntegration -> fatal). Force every Resolve GUI binary onto
      # xcb (XWayland) without touching the rest of the session's apps.
      davinci-resolve-xcb = pkgs.symlinkJoin {
        name = "davinci-resolve-xcb";
        paths = [ pkgs.davinci-resolve ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          for bin in $out/bin/*; do
            wrapProgram "$bin" --set QT_QPA_PLATFORM xcb
          done
        '';
      };
    in
    {
      nixpkgs.overlays = [
        (final: prev: {
          davinci-resolve = prev.callPackage (
            prev.runCommand "davinci-resolve-21-package.nix" { } ''
              substitute ${prev.path}/pkgs/by-name/da/davinci-resolve/package.nix $out \
                --replace-fail 'version = "20.3.3"' 'version = "21.0"' \
                --replace-fail 'sha256-2pfJz71fS/oEmK3n4cESKb9EDYCeDBhbzGLgFpb+OLI=' 'sha256-wte3N9t3SVKIInZAI0JAZzr/t8CXdIJuBvHgpw1iUcU=' \
                --replace-fail 'sha256-q5VGp0kkno//nYtT82QDZDJG92uumAtomUK4B55795g=' 'sha256-XIJpmlk1cNd4Fv4iXd6hnauKVJka1kiq2/OAf1hIsbw='
            ''
          ) { };
        })
      ];

      environment.systemPackages = [ davinci-resolve-xcb ];

      # Resolve needs an OpenCL runtime to drive the GPU or it exits silently at
      # startup. gaming.nix installs rocmPackages.clr but not the `.icd` output,
      # so no vendor ICD (amdocl64.icd) lands in /run/opengl-driver and the
      # OpenCL platform list is empty. Register it here (AMD RDNA-class GPUs).
      hardware.graphics.extraPackages = [ pkgs.rocmPackages.clr.icd ];

      # Activate the udev rules the package ships for Blackmagic hardware
      # (color panels, Speed Editor, Editor Keyboard). A bare systemPackages
      # entry doesn't pick these up.
      services.udev.packages = [ pkgs.davinci-resolve ];
    };
}

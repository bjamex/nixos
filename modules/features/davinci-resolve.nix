{ ... }:
{
  # DaVinci Resolve (free edition) from nixpkgs (21.x since 2026-07).
  # The 20.3.3 -> 21.0 version-bump overlay that used to live here broke once
  # nixpkgs merged its own bump (the substitute pattern stopped matching).
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

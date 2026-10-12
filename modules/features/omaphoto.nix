# OmaPhoto — a layered image editor for Linux (a port of Compositor): layers,
# masks, selections, RAW/HEIF import, and an ONNX-backed Remove Background
# (U²-Net model fetched and baked in at build time).
#
# Not in nixpkgs — pulled from the upstream flake (inputs.omaphoto), pinned to
# a release tag in flake.nix. It's a C++/Qt 6 source build with no binary
# cache, so the first rebuild compiles it. To update: bump the tag in
# flake.nix, then `nix flake update omaphoto`.
{ inputs, ... }:
{
  flake.nixosModules.omaphoto =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.omaphoto.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
}

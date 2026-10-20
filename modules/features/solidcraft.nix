# SolidCraft — parametric 3D CAD (sketch → constrain → extrude, STEP/STL/3MF
# in and out) in pure Rust, wgpu UI. Ships two binaries: `solidcraft` (the GUI)
# and `solidcraft-cli` (headless + MCP server).
#
# Not in nixpkgs — pulled from the upstream flake (inputs.solidcraft), pinned to
# a release tag in flake.nix, same as lightcraft.nix. Unlike LightCraft's,
# upstream's package already disables tests and wraps dbus/wayland/X11/Vulkan
# onto LD_LIBRARY_PATH, so it's used as-is. Rust source build with no binary
# cache, so the first rebuild compiles it.
# To update: bump the tag in flake.nix, then `nix flake update solidcraft`. If
# a bump adds a git dependency to Cargo.lock, the build fails on a missing
# outputHash — override cargoDeps the way lightcraft.nix does.
#
# It claims model/stl, model/3mf and model/step in its desktop entry; the
# openers for those are pinned in common.nix.
{ inputs, ... }:
{
  flake.nixosModules.solidcraft =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        inputs.solidcraft.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };
}

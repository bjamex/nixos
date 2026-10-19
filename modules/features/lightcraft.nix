# LightCraft — photo library and non-destructive raw developer (a clean-room
# Lightroom reimplementation in pure Rust, wgpu/Vulkan UI). Ships two binaries:
# `lightcraft` (the GUI) and `lightcraft-cli` (headless renderer + MCP server).
#
# Not in nixpkgs — pulled from the upstream flake (inputs.lightcraft), pinned to
# a release tag in flake.nix. It's a Rust source build with no binary cache, so
# the first rebuild compiles it. doCheck is off: upstream's package runs the
# whole workspace test suite single-threaded, which only slows the rebuild.
# To update: bump the tag in flake.nix, then `nix flake update lightcraft`.
#
# Gotcha: since v0.7 Cargo.lock pulls craft-ui from git (storytold/craft-libs),
# but upstream's package.nix still assumes crates.io only and gives no hash for
# it, so its build fails. cargoDeps is rebuilt here with the missing
# outputHash; when a bump moves craft-ui's rev, set it to lib.fakeHash, build,
# and paste the hash from the error.
#
# Gotcha: rfd (the file-dialog crate) dlopen()s libdbus-1.so to reach the
# xdg-desktop-portal, and upstream's package.nix leaves dbus out of its
# LD_LIBRARY_PATH — so Open Folder / Import did nothing (rfd fell back to
# zenity, which isn't installed). Re-wrapped here via symlinkJoin rather than
# overrideAttrs so adding the lib doesn't recompile the Rust.
{ inputs, ... }:
{
  flake.nixosModules.lightcraft =
    { pkgs, ... }:
    let
      upstream = inputs.lightcraft.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs {
        doCheck = false;
        cargoDeps = pkgs.rustPlatform.importCargoLock {
          lockFile = "${inputs.lightcraft}/Cargo.lock";
          outputHashes."craft-ui-0.1.0" = "sha256-VhLeT7VLdZAIz6gR9PdFI34IJxHsGF8NE0uzFCN2vIU=";
        };
      };

      lightcraft = pkgs.symlinkJoin {
        name = "lightcraft-${upstream.version}";
        paths = [ upstream ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          for bin in lightcraft lightcraft-cli; do
            wrapProgram $out/bin/$bin --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.dbus ]}"
          done
        '';
      };
    in
    {
      environment.systemPackages = [ lightcraft ];
    };
}

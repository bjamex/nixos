{ self, inputs, ... }: {
  flake.nixosModules.rustyPob = { pkgs, ... }:
  let
    rusty-path-of-building = pkgs.rusty-path-of-building.overrideAttrs (_: {
      version = "0.2.18";
      src = pkgs.fetchzip {
        url = "https://github.com/meehl/rusty-path-of-building/archive/refs/tags/v0.2.18.tar.gz";
        hash = "sha256-9YHXTUtTJO3GPf+NqASEkxf+a94doBGTjLyYruuxRg4=";
      };
      cargoDeps = pkgs.rustPlatform.importCargoLock {
        lockFile = ./rusty-path-of-building-Cargo.lock;
      };
    });
  in
  {
    environment.systemPackages = [ rusty-path-of-building ];
  };
}

{ self, inputs, ... }: {
  flake.nixosModules.rustyPob = { pkgs, ... }: {
    # rusty-path-of-building (PoE build planner) straight from nixpkgs. We used
    # to override src/version/cargoDeps to a newer tag while nixpkgs lagged, but
    # nixpkgs now ships the same version with a cached binary — so the plain
    # package builds faster and updates come free with `nix flake update`.
    # If nixpkgs falls behind again, reintroduce an overrideAttrs with a fresh
    # src hash + vendored Cargo.lock (see git history for the pattern).
    environment.systemPackages = [ pkgs.rusty-path-of-building ];
  };
}

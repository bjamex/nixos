{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-pinned.url = "github:nixos/nixpkgs/b12141ef619e0a9c1c84dc8c684040326f27cdcc";
    # open-webui pin: last unstable rev whose 0.10.1 matches the DB schema in
    # /var/lib/open-webui (0.10.x migrated it; 26.05's 0.9.6 can no longer read
    # it, and 0.10.2 fails its Svelte build). Drop once main ships a fixed 0.10.x.
    nixpkgs-openwebui.url = "github:nixos/nixpkgs/9e92285f211dad236540fd617d7e30e0b99bc0e1";
    nixpkgs-ollama.url = "github:NixOS/nixpkgs/nixos-26.05";

    flake-parts.url = "github:hercules-ci/flake-parts";
    lix-module = {
      # main, not stable: stable sits at the 2.92-era module while lixFromNixpkgs
      # ships Lix 2.95.x, which the older module warns about on every eval.
      url = "https://git.lix.systems/lix-project/nixos-module/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-citizen = {
      url = "github:LovingMelody/nix-citizen";
      inputs.nix-gaming.follows = "nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helium = {
      url = "github:amaanq/helium-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake 
    {inherit inputs;} 
    (inputs.import-tree ./modules);
}

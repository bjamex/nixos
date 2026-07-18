{ inputs, ... }: {

  flake.nixosModules.llm = { pkgs, ... }:
  let
    # Import (not legacyPackages) so allowUnfree applies — this instance is
    # separate from the system nixpkgs, and open-webui carries the unfree
    # "Open WebUI License".
    pkgs-ollama = import inputs.nixpkgs-ollama {
      system = pkgs.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  in {
    services.ollama = {
      enable = true;
      package = pkgs-ollama.ollama-rocm;
      rocmOverrideGfx = "11.0.0"; # gfx1201 has no Tensile library yet; RDNA3 kernels work on RDNA4
      host = "127.0.0.1";
    };

    services.open-webui = {
      enable = true;
      # main nixpkgs' open-webui 0.10.2 fails its Svelte build (invalid
      # self-closing tags) on the 2026-07 bump; the nixos-26.05 pin has a
      # working 0.9.6. Drop this once main ships a fixed 0.10.x.
      package = pkgs-ollama.open-webui;
      host = "127.0.0.1";
      port = 8080;
    };
  };
}

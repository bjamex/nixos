{ inputs, ... }: {

  flake.nixosModules.llm = { pkgs, ... }:
  let
    pkgs-ollama = inputs.nixpkgs-ollama.legacyPackages.${pkgs.system};
  in {
    services.ollama = {
      enable = true;
      package = pkgs-ollama.ollama-rocm;
      rocmOverrideGfx = "11.0.0"; # gfx1201 has no Tensile library yet; RDNA3 kernels work on RDNA4
      host = "127.0.0.1";
    };

    services.open-webui = {
      enable = true;
      host = "127.0.0.1";
      port = 8080;
    };
  };
}

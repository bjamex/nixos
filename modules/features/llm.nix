{ ... }: {

  flake.nixosModules.llm = { pkgs, ... }: {
    services.ollama = {
      enable = true;
      package = pkgs.ollama-rocm;
      rocmOverrideGfx = "12.0.1"; # RX 9070 XT (RDNA4 / gfx1201)
    };

    services.open-webui = {
      enable = true;
      host = "127.0.0.1";
      port = 8080;
    };
  };
}

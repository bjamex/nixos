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
    pkgs-openwebui = import inputs.nixpkgs-openwebui {
      system = pkgs.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  in {
    services.ollama = {
      enable = true;
      package = pkgs-ollama.ollama-rocm;
      # No rocmOverrideGfx: the bundled ROCm 7.2 ships native gfx1201 kernels,
      # and forcing gfx1100 ISA on RDNA4 hung the MES (GPU reset, 2026-07-19).
      host = "127.0.0.1";
      environmentVariables = {
        # The vram-based default is 4096, which Open WebUI's prompts overflow —
        # ollama then truncates the input and thinking eats the rest, so chats
        # "think" but never answer. gemma4:12b + 16k KV fits 16 GB comfortably.
        OLLAMA_CONTEXT_LENGTH = "16384";
      };
    };

    services.open-webui = {
      enable = true;
      # 0.10.1 already migrated the DB in /var/lib/open-webui, so 26.05's 0.9.6
      # crashes on it (no such column: config.id); main's 0.10.2 fails its
      # Svelte build. Pin the 0.10.1 rev until main ships a fixed 0.10.x.
      package = pkgs-openwebui.open-webui;
      host = "127.0.0.1";
      # 8080 is taken by the odysseus searxng container
      port = 8081;
    };
  };
}

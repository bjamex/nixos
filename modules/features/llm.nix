{ inputs, ... }: {

  flake.nixosModules.llm =
    { pkgs, ... }:
    let
      # Import (not legacyPackages) so allowUnfree applies — this instance is
      # separate from the system nixpkgs, and open-webui carries the unfree
      # "Open WebUI License".
      pkgs-ollama = import inputs.nixpkgs-ollama {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
    in
    {
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
        # Uses the system nixpkgs (unstable) open-webui. Was pinned to a 0.10.1
        # rev while unstable's 0.10.2 failed its Svelte build; that's since fixed
        # (0.10.2 builds clean, 2026-07-28) and 0.10.2 is DB-schema-compatible
        # with the 0.10.1 data already migrated in /var/lib/open-webui, so the pin
        # (and its nixpkgs-openwebui input) is gone.
        package = pkgs.open-webui;
        host = "127.0.0.1";
        # 8080 is taken by the odysseus searxng container
        port = 8081;
      };

      # The open-webui unit runs with a restricted PATH (it does not inherit
      # environment.systemPackages / current-system sw/bin), so ffmpeg has to be
      # added to the service PATH explicitly for its audio/voice transcription —
      # the system-wide ffmpeg in common.nix is only visible to user shells.
      systemd.services.open-webui.path = [ pkgs.ffmpeg ];
    };
}

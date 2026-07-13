{ self, inputs, ... }:
{

  flake.nixosModules.hadesConfiguration =
    { pkgs, lib, ... }:
    {
      imports = [
        self.nixosModules.hadesHardware
        self.nixosModules.hadesDisk
        self.nixosModules.tailscale
        self.nixosModules.secretspec # secrets wiring for migrated services
      ];

      # --- Nix ---
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      nixpkgs.config.allowUnfree = true;

      # --- Boot ---
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      # --- Networking ---
      networking.hostName = "hades";
      networking.firewall.enable = true;
      networking.firewall.allowedTCPPorts = [ 22 ];

      # Headless server — no local console once deployed, so SSH stays on
      # (styx/void disable it since they're reachable in person + Tailscale).
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      # --- Locale & Time ---
      time.timeZone = "Australia/Brisbane";
      i18n.defaultLocale = "en_AU.UTF-8";

      # --- Memory ---
      # Only 16GB RAM (vs. Proxmox's 128GB), so lean on zram to stretch it
      # before revisiting a hardware upgrade — see docs/hades-roadmap.md.
      zramSwap.enable = true;

      # --- Secrets ---
      # Google Cloud Secret Manager. Auth via a service-account key placed
      # root-only on the box (out-of-band, never committed) — see the GCP
      # setup steps in docs/hades-roadmap.md.
      services.secretspec.provider = "gcsm://REPLACE-WITH-GCP-PROJECT-ID"; # TODO: real project id
      services.secretspec.providerEnvironment.GOOGLE_APPLICATION_CREDENTIALS =
        "/var/lib/secretspec/gcp-sa.json";

      # --- Virtualisation ---
      # podman backend for oci-containers, used to migrate services off the
      # Proxmox Docker host (see docs/hades-roadmap.md).
      virtualisation.oci-containers.backend = "podman";

      # --- Users ---
      users.users.swin = {
        isNormalUser = true;
        description = "Brett James";
        extraGroups = [ "wheel" ];
        # SSH key is injected at deploy time, not committed here — see
        # docs/hades-roadmap.md (Phase 1).
        openssh.authorizedKeys.keys = [ ];
      };

      # --- Packages ---
      environment.systemPackages = with pkgs; [
        git
        vim
      ];

      system.stateVersion = "25.11";
    };
}

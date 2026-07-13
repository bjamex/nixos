{ self, inputs, ... }:
{

  flake.nixosModules.hadesConfiguration =
    { pkgs, lib, ... }:
    {
      imports = [
        self.nixosModules.hadesHardware
        self.nixosModules.tailscale
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

      # --- Virtualisation ---
      # podman backend for oci-containers, used to migrate services off the
      # Proxmox Docker host (see docs/hades-roadmap.md).
      virtualisation.oci-containers.backend = "podman";

      # --- Users ---
      users.users.swin = {
        isNormalUser = true;
        description = "Brett James";
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = [
          # TODO: add your SSH public key(s) here before first deploy
        ];
      };

      # --- Packages ---
      environment.systemPackages = with pkgs; [
        git
        vim
      ];

      system.stateVersion = "25.11";
    };
}

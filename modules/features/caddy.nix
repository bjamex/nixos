{ self, inputs, ... }:
{
  # Reverse proxy for *.swinlab.net on hades. Declarative alternative to the
  # Nginx Proxy Manager box on Proxmox — every vhost lives in the flake, and
  # individual service modules add their own `services.caddy.virtualHosts.<host>`.
  #
  # TLS: services are tailnet-only (Cloudflare DNS records point at hades'
  # Tailscale IP), so HTTP-01 can't reach us — certs are issued via ACME DNS-01
  # against Cloudflare. Caddy is built with the caddy-dns/cloudflare plugin, and
  # the API token comes from the secrets provider (see secretspec.nix), never
  # committed. No ACME email is set (Caddy uses an anonymous account) to keep
  # the address out of the repo.
  flake.nixosModules.caddy =
    { config, lib, pkgs, ... }:
    let
      caddyWithCloudflare = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
        # Go-modules vendor hash; changes whenever nixpkgs bumps caddy/Go — refresh
        # from the build's "got:" on a hash mismatch (last: 2026-07-26 nixpkgs bump).
        hash = "sha256-7GoH8YLCoPmPExQxoga2FHB58zQDoZVf1BBwkVi0SsQ=";
      };
    in
    {
      # Cloudflare API token (Zone.DNS edit for swinlab.net) for ACME DNS-01,
      # resolved into caddy.service's environment by the secretspec oneshot.
      services.secretspec.secrets.caddy.prefix = "CLOUDFLARE_";

      services.caddy = {
        enable = true;
        package = caddyWithCloudflare;
        globalConfig = ''
          acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        '';
        environmentFile = config.services.secretspec.secrets.caddy.envFile;
      };

      # Expose 80/443 only on the Tailscale interface — never publicly.
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
        80
        443
      ];
    };
}

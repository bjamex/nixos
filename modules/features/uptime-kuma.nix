{ self, inputs, ... }:
{
  # Pilot migration (Phase 4): Uptime Kuma as an oci-container behind Caddy.
  # Exercises the full pipeline end-to-end — podman container + persistent
  # volume + tailnet-only reverse-proxy vhost with a real *.swinlab.net cert.
  # (The secrets path is exercised separately by Caddy's Cloudflare token.)
  flake.nixosModules.uptimeKuma =
    { config, lib, ... }:
    {
      virtualisation.oci-containers.containers.uptime-kuma = {
        image = "louislam/uptime-kuma:1";
        # Bind to loopback only — reachable solely through the Caddy vhost below.
        ports = [ "127.0.0.1:3001:3001" ];
        volumes = [ "/var/lib/uptime-kuma:/app/data" ];
      };

      # Persistent state dir (SQLite lives here); survives rebuilds and reboots.
      systemd.tmpfiles.rules = [ "d /var/lib/uptime-kuma 0750 root root - -" ];

      services.caddy.virtualHosts."status.swinlab.net".extraConfig = ''
        reverse_proxy 127.0.0.1:3001
      '';
    };
}

# Tdarr node: styx's RX 9070 XT does the transcoding for the Tdarr server on
# docker-prod-2 (192.168.0.101:8266), which has no GPU. One GPU worker re-encodes
# the library to HEVC via VAAPI (flow "HEVC (styx GPU)" on the server).
#
# Gotchas:
#  - Runs the upstream Docker image, not nixpkgs' services.tdarr: the node must
#    match the server's version (3.x), and nixpkgs is on 2.x. `pull = "always"`
#    keeps it in step with the server, which Dockhand auto-updates weekly.
#  - The image's Mesa (25.2+) is what makes VAAPI work on RDNA4 (gfx1201).
#  - Paths are "mapped": the node sees the same /media and /temp as the server,
#    both bound from the /mnt/data SMB share. /mnt/data is an automount, hence
#    rslave propagation and RequiresMountsFor. transcode_cache must stay
#    writable over SMB (a Windows NTACL on it once blocked that).
#  - Worker limits live on the server, not here: styx = 1 GPU transcode worker,
#    everything else 0. Set them in the web UI (192.168.0.101:8265 → Nodes).
{ ... }:
{
  flake.nixosModules.tdarrNode = {
    virtualisation.oci-containers = {
      backend = "docker"; # docker is already enabled in common.nix
      containers.tdarr-node = {
        image = "ghcr.io/haveagitgat/tdarr_node:latest";
        pull = "always";
        environment = {
          TZ = "Australia/Brisbane";
          PUID = "1000";
          PGID = "1000";
          UMASK_SET = "002";
          nodeName = "styx";
          serverURL = "http://192.168.0.101:8266";
          serverIP = "192.168.0.101";
          serverPort = "8266";
          inContainer = "true";
          ffmpegVersion = "7";
          nodeType = "mapped";
        };
        volumes = [
          "/var/lib/tdarr-node/configs:/app/configs"
          "/var/lib/tdarr-node/logs:/app/logs"
          "/mnt/data:/media:rslave"
          "/mnt/data/transcode_cache:/temp"
        ];
        extraOptions = [ "--device=/dev/dri:/dev/dri" ];
      };
    };

    systemd = {
      tmpfiles.rules = [
        "d /var/lib/tdarr-node 0755 swin users - -"
        "d /var/lib/tdarr-node/configs 0755 swin users - -"
        "d /var/lib/tdarr-node/logs 0755 swin users - -"
      ];
      services.docker-tdarr-node.unitConfig.RequiresMountsFor = [ "/mnt/data/transcode_cache" ];
    };
  };
}

{ self, inputs, ... }:
{
  # Disk layout for the OptiPlex 7080's single 256GB SSD. disko partitions and
  # formats it during `nixos-anywhere --flake .#hades`, and generates the
  # matching `fileSystems` entries — which is why hardware-configuration.nix no
  # longer declares `/`, `/boot`, `/nix`, or `/var` itself.
  #
  # btrfs with subvolumes + zstd compression: cheap snapshots of service state
  # (`/var`, which holds container volumes and the pass store) independent of the
  # OS, and compression to stretch the SSD. Bulk data lives on the Proxmox NFS
  # pool, not here.
  #
  # IMPORTANT: confirm the device path on the box before the first deploy. An
  # OptiPlex 7080 may present the SSD as /dev/sda (SATA) or /dev/nvme0n1 (NVMe);
  # run `lsblk` in the live installer to check, and update `device` below.
  flake.nixosModules.hadesDisk =
    { ... }:
    {
      disko.devices.disk.main = {
        type = "disk";
        device = "/dev/sda"; # TODO: confirm with lsblk before deploy
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "512M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # force overwrite any existing signature
                subvolumes = {
                  "/root" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                  "/var" = {
                    mountpoint = "/var";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
}

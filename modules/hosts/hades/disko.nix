{ self, inputs, ... }:
{
  # Disk layout for the OptiPlex 7080's single 256GB SSD. disko partitions and
  # formats it during `nixos-anywhere --flake .#hades`, and generates the
  # matching `fileSystems` entries — which is why hardware-configuration.nix no
  # longer declares `/` or `/boot` itself.
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
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
}

{ ... }:
{
  flake.nixosModules.smb = { ... }: {
    fileSystems."/mnt/data" = {
      device = "//192.168.0.100/data";
      fsType = "cifs";
      options = [
        "credentials=/etc/smb-credentials"
        "uid=1000"
        "gid=1000"
        "file_mode=0644"
        "dir_mode=0755"
        "vers=3.0"
        "nofail"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.requires=network-online.target"
      ];
    };
  };
}

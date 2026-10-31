# builder — NixOS LXC (CT 160) on the Proxmox host (pve, 192.168.0.99) that
# styx offloads Nix builds to: 32 cores / 48 GB, 150 GB rootfs on local-lvm
# (the boot SSD, kept off the degraded `rust` pool). The R730 is due to be
# sold, so treat this host as temporary.
#
# Created from the NixOS LXC template with
#   pct create 160 … --ostype nixos --unprivileged 1 --features nesting=1
# WITHOUT --ssh-public-keys: the template has no /root, so PVE's key-injection
# hook crashes and rolls the whole create back. Push the key afterwards with
# `pct push` + `pct exec` (PATH must be set explicitly inside pct exec). Root's
# authorized_keys live on the container, not here — same policy as hades.
#
# Deploy from styx, building on the container itself:
#   nixos-rebuild switch --flake .#builder \
#     --target-host root@192.168.0.160 --build-host root@192.168.0.160
#
# The IP comes from Proxmox: proxmox-lxc.nix turns on networkd, which reads
# the eth0.network PVE writes (static 192.168.0.160). The first switch from the
# 24.05 template leaves the old logind running (user@0 fails with "Invalid
# session class manager-early") — `pct reboot 160` once after it.
{ self, ... }:
{
  flake.nixosModules.builderConfiguration =
    { modulesPath, ... }:
    {
      imports = [
        (modulesPath + "/virtualisation/proxmox-lxc.nix")
        self.nixosModules.nixCore # nix daemon policy + weekly GC (shared)
        self.nixosModules.caDistrust # leaked-CA root blocklist (shared)
      ];

      nixpkgs.hostPlatform = "x86_64-linux";

      # --- Networking ---
      # PVE doesn't write /etc/hostname for ostype=nixos (NixOS owns /etc), so
      # the module's "take the hostname from Proxmox" default leaves it as
      # `nixos`; set it here instead. The IP still comes from PVE (networkd).
      proxmoxLXC.manageHostName = true;
      networking.hostName = "builder";

      # --- Nix ---
      # styx's nix-daemon connects as root, which is trusted by default.
      # Outputs get copied back to styx, so this store is only a cache: GC as
      # soon as it runs low rather than waiting for nixCore's weekly run.
      nix.settings = {
        min-free = 20 * 1024 * 1024 * 1024;
        max-free = 60 * 1024 * 1024 * 1024;
      };

      # --- SSH ---
      services.openssh.settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };

      time.timeZone = "Australia/Brisbane";

      system.stateVersion = "24.05"; # the LXC template's release
    };
}

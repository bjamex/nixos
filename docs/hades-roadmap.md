# Roadmap: Proxmox → NixOS (hades) home server migration

## Context

Migrating home server workloads off Proxmox (128GB RAM, 32TB storage, ~5TB used,
running Docker containers) onto a Dell OptiPlex 7080 (i5-10500, 16GB RAM, 256GB SSD)
running NixOS, with the eventual goal of NixOS fully replacing Proxmox.

**Constraint to keep in mind throughout:** the OptiPlex has 16GB RAM vs. Proxmox's
128GB. It won't be a 1:1 replacement as-is — be selective about what runs here
initially, and revisit hardware (RAM upgrade, or a dedicated storage box) once it's
clear which services are staying long-term.

`hades` lives in this repo alongside `styx`/`void` rather than a separate one, so
feature modules (`modules/features/tailscale.nix`, etc.) and the user module
(`modules/users/swin.nix`) are shared across all three machines instead of
duplicated.

## Decisions made

**Config management:** flake-based NixOS config (already true of this whole repo),
deployed with `nixos-anywhere` (build the flake ahead of time on any machine —
only `hardware-configuration.nix` is hardware-specific — then install over SSH
once the OptiPlex is racked).

**Container/service strategy (hybrid):**
- Prefer native NixOS modules where a solid one exists (`services.adguardhome`,
  `services.home-assistant`, `services.jellyfin`, `services.caddy`/`nginx`,
  `services.immich`, etc.) — more "NixOS-native," less overhead.
- Everything else goes through `virtualisation.oci-containers` (podman backend,
  already set in `modules/hosts/hades/configuration.nix`) so container
  definitions stay declarative in Nix instead of imperative
  `docker-compose.yml` files.
- Deliberately not just running the Docker daemon + existing compose files
  long-term — fastest short-term path, but works against the "replace Proxmox"
  goal.

**Storage:** keep the 32TB pool on Proxmox (or a NAS VM/LXC on it) as the backend
for now; mount it into NixOS declaratively via NFS in `fileSystems`. Don't try to
fit media/bulk data on the 256GB SSD.

**Secrets:** [SecretSpec](https://secretspec.dev) — declare required secrets per
service in `secretspec.toml` (root of this repo, `name = "hades"`), values stored
in a provider backend (system keyring for a single-box setup). No official NixOS
module exists yet, so secrets get resolved via an `ExecStartPre` on the systemd
unit `oci-containers`/native services generate, writing a resolved env file that
`environmentFiles` then points at (see the Phase 3 example below once a real
service is added).

## Phased roadmap

**Phase 0 — Prep** ✅ done
- Flakes/flake-parts already in place (shared with styx/void), SecretSpec chosen
  for secrets, `hades` folded into this repo as a third host.

**Phase 1 — Base install & config skeleton** — in progress
- `modules/hosts/hades/{default,configuration,hardware-configuration}.nix`
  scaffolded, matching the styx/void convention. Still needed before deploy:
  - Add SSH public key(s) to `modules/hosts/hades/configuration.nix`
    (`users.users.swin.openssh.authorizedKeys.keys` is empty)
  - Firm up static IP / DHCP reservation once the network layout is known
  - Once the OptiPlex is in hand: boot it into a live Linux env with SSH enabled,
    then from another machine run
    `nixos-anywhere --flake .#hades root@<optiplex-ip>` to partition, install, and
    deploy in one shot. Pull the real `hardware-configuration.nix` it generates
    back into `modules/hosts/hades/hardware-configuration.nix` afterward
    (replacing the current placeholder, keeping the `flake.nixosModules.hadesHardware`
    wrapper).

**Phase 2 — Storage integration**
- Export relevant datasets from the Proxmox-side 32TB pool via NFS.
- Mount declaratively in NixOS's `fileSystems` (with automount options) —
  add directly in `modules/hosts/hades/configuration.nix`, or as a new
  `modules/features/nfs-mounts.nix` if it ends up reused elsewhere.
- Mirror the mount point structure used by existing Docker volumes (e.g.
  `/mnt/media`) to ease compose → native/oci-container translation later.

**Phase 3 — Services module pattern**
- `virtualisation.oci-containers` already wired (podman backend).
- Each migrated service becomes its own self-registering file under
  `modules/features/`, e.g. `modules/features/adguard.nix`:
  ```nix
  { ... }:
  {
    flake.nixosModules.adguard = { config, pkgs, ... }:
      {
        virtualisation.oci-containers.containers.adguard = {
          image = "adguard/adguardhome";
          ports = [ "53:53/tcp" "53:53/udp" "3000:3000/tcp" ];
          volumes = [ "/var/lib/adguard/work:/opt/adguardhome/work" ];
          environmentFiles = [ "/run/secretspec/adguard.env" ];
        };
        systemd.services.podman-adguard.serviceConfig.ExecStartPre = [
          "${pkgs.coreutils}/bin/mkdir -p /run/secretspec"
          "${pkgs.bash}/bin/bash -c '${pkgs.secretspec}/bin/secretspec run --provider keyring -- env | grep ^ADGUARD_ > /run/secretspec/adguard.env'"
        ];
      };
  }
  ```
  Then add `self.nixosModules.adguard` to `modules/hosts/hades/configuration.nix`'s
  `imports` list — same direct-inclusion style styx/void already use, no
  enable-flag toggles needed since each feature module only gets imported by the
  hosts that actually want it.
  (`pkgs.secretspec` isn't in nixpkgs yet — pull it from its own flake output or
  `buildRustPackage` until it lands.)
- Infrastructure only for now — no services actually migrated yet.

**Phase 4 — Pilot migration**
- Migrate one low-risk, low-state service first (e.g. Pi-hole/AdGuard or Uptime
  Kuma) — not the media stack. Validates the full pipeline: storage mount,
  secrets, networking, reverse proxy, backups. Document the process as a template.
  Run in parallel with the Proxmox original during a burn-in period.

**Phase 5 — Expand in waves**
- Migrate remaining services in small batches, ordered by risk/complexity.
- Track RAM budget; explicitly decide what stays on Proxmox vs. moves to hades.

**Phase 6 — Networking/reverse proxy**
- Reverse proxy (Caddy/nginx, native module) + internal DNS so hostnames stay
  consistent as services move between hosts.

**Phase 7 — Backups & rollback**
- NixOS generations handle config rollback for free; still need real data backups
  (restic or similar) for state directories/volumes before decommissioning the
  Proxmox copy of a migrated service.

**Phase 8 — Eventual Proxmox decommission**
- Only after critical services are migrated and burned in, and the long-term
  storage plan is settled (repurpose Proxmox as a dedicated storage box, or
  replace it too).

## Verification checkpoints

- Phase 1: `nixos-rebuild switch --flake .#hades` succeeds, SSH access works,
  survives a reboot.
- Phase 2: NFS share mounts and persists across reboot (declarative, not manual).
- Phase 4: pilot service reachable, data persists across `nixos-rebuild switch`
  and reboot, and can be rebuilt from the flake + backup alone.
- Ongoing: keep the Proxmox original of each migrated service running until its
  NixOS replacement has been stable for 1-2 weeks.

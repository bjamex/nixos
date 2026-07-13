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
service in `secretspec.toml` (root of this repo, `name = "hades"`, non-secret:
names + descriptions only). `pkgs.secretspec` is now in nixpkgs (≥0.12), so no
`buildRustPackage` needed.

- **Provider:** **Google Cloud Secret Manager** (`gcsm://<project-id>`). Chosen
  over dotenv/keyring for managed rotation + versioning + IAM + audit logging,
  and to build transferable GCP experience. The nixpkgs `secretspec` build
  already includes the `gcsm` feature (verified). `keyring` was rejected (needs
  an unlocked D-Bus Secret Service — impractical headless).
  - **Tradeoff accepted:** secrets resolve at container start / boot, so a
    service won't start if GCP/internet is unreachable at that moment. Fine for
    this setup; revisit if offline-boot resilience becomes important.
  - **Auth:** Application Default Credentials via a service-account JSON key at
    `/var/lib/secretspec/gcp-sa.json` (root-only, placed out-of-band — e.g.
    `nixos-anywhere --extra-files` — never committed). Wired via
    `services.secretspec.providerEnvironment.GOOGLE_APPLICATION_CREDENTIALS`.
- **Wiring:** `modules/features/secretspec.nix` (the `secretspec` module,
  already imported by hades) turns this into reusable glue. A service declares
  what it needs via `services.secretspec.secrets.<unit>.prefix = "FOO_"`; the
  module adds a privileged `ExecStartPre` that runs `secretspec run` to resolve
  those secrets into a root-only `/run/secretspec/<unit>.env`, exposed as
  `.envFile` for the unit's `environmentFiles`. Automated access passes a
  `--reason` (SecretSpec ≥0.12 requires one for agent access; recorded in the
  audit log).

### GCP one-time setup (before the pilot service)

Do this once, from any machine with `gcloud` (or the Cloud Console):

1. **Create a project** (id must be globally unique), and note it — this is the
   `<project-id>` in `services.secretspec.provider` (currently a `REPLACE-…`
   placeholder in `modules/hosts/hades/configuration.nix`):
   `gcloud projects create <project-id>` (and link a billing account — Secret
   Manager has a free tier; beyond it, pennies/month at home scale).
2. **Enable the API:** `gcloud services enable secretmanager.googleapis.com --project <project-id>`
3. **Create a service account** for hades to read secrets:
   `gcloud iam service-accounts create hades-secrets --project <project-id>`
4. **Grant it read-only access** (accessor, *not* admin):
   ```
   gcloud projects add-iam-policy-binding <project-id> \
     --member "serviceAccount:hades-secrets@<project-id>.iam.gserviceaccount.com" \
     --role roles/secretmanager.secretAccessor
   ```
5. **Create a key** and keep it safe (this file is the one bootstrap secret):
   `gcloud iam service-accounts keys create gcp-sa.json --iam-account hades-secrets@<project-id>.iam.gserviceaccount.com`
6. **Place it on hades** as `/var/lib/secretspec/gcp-sa.json`, `chmod 600`, owned
   by root (the `secretspec` module's tmpfiles rule creates the dir). At install
   time this is easiest via `nixos-anywhere --extra-files`.

Then set/rotate values (for setting you'll want a broader role like
`secretmanager.admin` on your own user, not the hades accessor SA):
`secretspec set FOO_TOKEN --provider gcsm://<project-id> --reason "…"`, and
`secretspec check --provider gcsm://<project-id>` to confirm the spec is met.

## Phased roadmap

**Phase 0 — Prep** ✅ done
- Flakes/flake-parts already in place (shared with styx/void), SecretSpec chosen
  for secrets, `hades` folded into this repo as a third host.

**Phase 1 — Base install & config skeleton** — in progress
- `modules/hosts/hades/{default,configuration,hardware-configuration}.nix`
  scaffolded, matching the styx/void convention.
- ✅ SSH public key added (`users.users.swin.openssh.authorizedKeys.keys`).
- ✅ disko layout added (`modules/hosts/hades/disko.nix`, `hadesDisk` module):
  single-disk GPT, 512M ESP → `/boot` + ext4 `/`. disko now owns `fileSystems`,
  so the placeholder `hardware-configuration.nix` no longer declares them.
- ✅ zram swap enabled to stretch the 16GB RAM.
- Still needed before deploy:
  - Confirm the SSD device path in `disko.nix` (`/dev/sda` placeholder) — run
    `lsblk` on the OptiPlex live installer; it may be `/dev/nvme0n1` instead.
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
  `modules/features/`. Secrets are handled by the shared `secretspec` module
  (see the Secrets section above) — declare the prefix, reference its env file,
  no hand-rolled ExecStartPre. e.g. `modules/features/adguard.nix`:
  ```nix
  { ... }:
  {
    flake.nixosModules.adguard =
      { config, ... }:
      {
        services.secretspec.secrets.podman-adguard.prefix = "ADGUARD_";
        virtualisation.oci-containers.containers.adguard = {
          image = "adguard/adguardhome";
          ports = [ "53:53/tcp" "53:53/udp" "3000:3000/tcp" ];
          volumes = [ "/var/lib/adguard/work:/opt/adguardhome/work" ];
          # env file that the secretspec module resolves at start:
          environmentFiles = [ config.services.secretspec.secrets.podman-adguard.envFile ];
        };
      };
  }
  ```
  Then declare `ADGUARD_ADMIN_PASSWORD = { ... }` under `[profiles.default]` in
  `secretspec.toml`, and add `self.nixosModules.adguard` to
  `modules/hosts/hades/configuration.nix`'s `imports` list — same
  direct-inclusion style styx/void already use, no enable-flag toggles needed
  since each feature module only gets imported by the hosts that want it.
- Infrastructure only for now — no services actually migrated yet.

**Phase 4 — Reverse proxy + pilot migration** — in progress
- Reverse proxy brought forward from Phase 6: it's foundational, since every
  migrated service sits behind it. **Caddy** chosen over nginx and the current
  Nginx Proxy Manager box — NPM keeps its proxy hosts as imperative GUI/DB
  state, the opposite of the declarative goal; Caddy declares every vhost in the
  flake with far less boilerplate.
  - `modules/features/caddy.nix` (`caddy` module): Caddy built via
    `withPlugins` with `caddy-dns/cloudflare@v0.2.4`. Services are **tailnet-only**
    (Cloudflare A records point at hades' Tailscale IP), so certs use **ACME
    DNS-01** against Cloudflare — HTTP-01 can't reach a tailnet host. The
    Cloudflare API token is the first real secret through the GCSM pipeline
    (`CLOUDFLARE_API_TOKEN`, prefix `CLOUDFLARE_`). 80/443 are opened *only* on
    `tailscale0`; no ACME email is set (kept out of the repo).
  - Each service adds its own `services.caddy.virtualHosts.<host>.swinlab.net`.
- Pilot service: **Uptime Kuma** (`modules/features/uptime-kuma.nix`) — an
  oci-container bound to loopback, persistent volume at `/var/lib/uptime-kuma`,
  fronted by `status.swinlab.net`. Chosen over AdGuard because it's HTTP-native
  (actually exercises the proxy) and low-stakes. **AdGuard is deferred** to its
  own DNS mini-project later — DNS is foundational/risky given the existing
  tailnet-DNS + swinlab.net search-domain interactions, and doesn't test the
  proxy.
- Together the two validate the pipeline end-to-end: GCSM secret → Caddy env,
  oci-container + persistent volume, tailnet-only reverse proxy with a real
  `*.swinlab.net` cert. Run in parallel with any Proxmox original during burn-in.

**Phase 5 — Expand in waves**
- Migrate remaining services in small batches, ordered by risk/complexity.
- Track RAM budget; explicitly decide what stays on Proxmox vs. moves to hades.
- First service that needs its own secret (e.g. an *arr API key) exercises the
  oci-container + secret combo (Uptime Kuma needed no secret of its own).

**Phase 6 — Internal DNS** (reverse proxy done in Phase 4)
- Internal DNS so hostnames stay consistent as services move between hosts; fold
  in the deferred AdGuard here if it becomes the DNS provider.

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

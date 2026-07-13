# styx

Personal + home server NixOS configuration for `styx` (desktop), `void` (laptop), and `hades` (home server). Managed with flakes and `flake-parts`; all `.nix` files under `modules/` are auto-loaded via `import-tree`.

## Structure

```
modules/
  hosts/styx/        # Desktop (AMD Ryzen + RX 9070 XT, dual 2560×1440@144)
  hosts/void/        # Laptop (Intel, LUKS encryption)
  hosts/hades/        # Home server (Dell OptiPlex 7080, headless) — see docs/hades-roadmap.md
  features/          # Feature modules imported by each host
  users/swin.nix     # Dotfiles via hjem (kitty, btop, nvim, vscode, GTK)
```

## Deploy

```bash
sudo nixos-rebuild switch --flake .#styx
sudo nixos-rebuild switch --flake .#void

# hades: deployed remotely, see docs/hades-roadmap.md
nixos-anywhere --flake .#hades root@<hades-ip>
```

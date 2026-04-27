# Changelog

All notable changes to this NixOS configuration are documented in this file.

## [1.1] - 2026-04-27

### Security

- **SSH hardening:** 
  - Disabled OpenSSH on all hosts

## [1.0] - 2026-04-27

### Added

- **Multi-host architecture:** Support for multiple PCs from single repository
  - `styx` — Desktop machine with fixed DP-1 monitor (2560x1440@143.973)
  - `void` — Laptop with dynamic monitor detection
  
- **Host modules:** Each host in `modules/hosts/` with own directory structure
  - `default.nix` — Registers nixosConfiguration
  - `configuration.nix` — Host-specific settings
  - `hardware-configuration.nix` — Hardware-specific setup

- **Niri refactor:** Split compositor config into reusable modules
  - `niri-base.nix` — Shared keybinds, layout, input settings
  - `niri-styx.nix` — Styx desktop monitor output config
  - `niri-void.nix` — Void laptop with auto-detect monitors

- **File manager module:** `fileManager.nix`
  - Dolphin file manager
  - KDE dependencies (qtsvg, kio, kio-fuse, kio-extras)
  - Placeholder for future yazi terminal file browser

- **Gaming updates:**
  - Moved xivlauncher to gaming.nix

- **Docker support:** In void configuration
  - `virtualisation.docker.enable = true`
  - Added swin user to docker group

- **New packages (void):**
  - docker, epsonscan2, freecad, google-earth-pro, nordpass
  - localsend, pdfarranger, sunshine, moonlight

- **Niri keybinds:**
  - `Mod+A` — Open Google Gemini webapp

- **Documentation:**
  - Updated README with multi-host structure and deployment instructions

### Changed

- **parts.nix:** Reduced systems from 4 architectures to x86_64-linux only
- **Module organization:** Features now support host-specific customization
- **Deployment:** Can now target specific hosts with `--flake .#styx` or `--flake .#void`

### Removed

- Old `niri.nix` (replaced with niri-base, niri-styx, niri-void)
- xivlauncher from system packages (now in gaming.nix)

## Deployment Commands

```bash
# Deploy to styx (desktop)
sudo nixos-rebuild switch --flake .#styx

# Deploy to void (laptop)
sudo nixos-rebuild switch --flake .#void
```

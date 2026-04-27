# NixOS Multi-Host Configuration

My personal NixOS configuration using flakes, supporting multiple hosts (styx desktop, void laptop).

## Structure

```
flake.nix                 # Flake inputs and outputs (flake-parts + import-tree)
modules/
  hosts/
    styx/
      default.nix         # Registers nixosConfigurations.styx
      configuration.nix   # Styx-specific settings
      hardware-configuration.nix
    void/
      default.nix         # Registers nixosConfigurations.void
      configuration.nix   # Void-specific settings (laptop)
      hardware-configuration.nix
  features/
    niri-base.nix         # Shared niri compositor settings
    niri-styx.nix         # Styx desktop monitor config
    niri-void.nix         # Void laptop with dynamic monitors
    gaming.nix            # Gaming (Steam, Lutris, xivlauncher)
    kitty.nix             # Kitty terminal
    neovim.nix            # Neovim via nixvim
    noctalia.nix          # Noctalia shell/launcher
    pipewire.nix          # Audio (ALSA, PulseAudio, JACK)
    fileManager.nix       # Dolphin file manager (KDE)
```

## Hosts

### styx
Desktop machine with fixed monitor setup (DP-1 @ 2560x1440@143.973)

### void
Laptop with dynamic monitor detection (built-in + external monitors)

## Deployment

```bash
# Deploy to styx
sudo nixos-rebuild switch --flake .#styx

# Deploy to void
sudo nixos-rebuild switch --flake .#void
```

## Features

- **Multi-host support:** Shared modules + host-specific configurations
- **Niri compositor:** Dynamic window manager (Wayland)
- **Gaming:** Steam, Lutris, Proton, with nix-gaming cachix
- **Audio:** PipeWire with low-latency gaming support
- **Terminal:** Kitty with Catppuccin Mocha
- **Editor:** Neovim via nixvim
- **File Manager:** Dolphin (KDE) with KIO support
- **Utilities:** Docker, Tailscale, SSH, NetworkManager


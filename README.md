# NixOS Multi-Host Configuration

My personal NixOS configuration using flakes, supporting multiple hosts (styx desktop, void laptop).

## Structure

```
flake.nix                 # Flake inputs and outputs (flake-parts + import-tree)
assets/
  wallpaper.jpg           # Wallpaper used by stylix for theming
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
    niri-base.nix         # Shared niri compositor settings, keybinds
    niri-styx.nix         # Styx desktop monitor config (DP-2 @ 2560x1440@143.973)
    niri-void.nix         # Void laptop with dynamic monitors
    gaming.nix            # Steam, Lutris, gamemode, mcpelauncher, xivlauncher
    kitty.nix             # Kitty terminal
    neovim.nix            # Neovim with LazyVim
    noctalia.nix          # Noctalia shell/launcher
    pipewire.nix          # Audio (ALSA, PulseAudio, JACK, EasyEffects, mono mic)
    fileManager.nix       # Nautilus file manager
    llm.nix               # Ollama (ROCm) + Open WebUI
    theming.nix           # Stylix system-wide theming (Tokyo Night Dark)
  users/
    swin.nix              # Home Manager config for user swin
```

## Hosts

### styx
Desktop machine (AMD Ryzen / RX 9070 XT) with dual monitor support (Dell AW2724DM on DP-2 @ 2560x1440@143.973).

### void
Laptop with dynamic monitor detection (built-in + external monitors).

## Deployment

```bash
# Deploy to styx
sudo nixos-rebuild switch --flake .#styx

# Deploy to void
sudo nixos-rebuild switch --flake .#void
```

## Features

- **Multi-host support:** Shared modules + host-specific configurations
- **Niri compositor:** Wayland window manager with rounded corners, focus ring, workspace keybinds
- **Theming:** System-wide Tokyo Night Dark via Stylix (GTK, Qt, app configs)
- **Home Manager:** Per-user declarative config via NixOS module integration
- **Gaming:** Steam, Lutris, gamemode, gamescope, Heroic, Minecraft Bedrock (mcpelauncher), XIV Launcher
- **Audio:** PipeWire with low-latency gaming support, EasyEffects, mono mic loopback
- **Browser:** Helium (privacy-focused Chromium) + Google Chrome
- **Terminal:** Kitty
- **Editor:** Neovim with LazyVim
- **File Manager:** Nautilus with gvfs and terminal integration
- **Local AI:** Ollama with ROCm (RX 9070 XT) + Open WebUI at localhost:8080
- **Utilities:** Docker, Tailscale, Sunshine/Moonlight, Flatpak, NetworkManager

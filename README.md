# NixOS Multi-Host Configuration

My personal NixOS configuration using flakes, supporting multiple hosts (styx desktop, void laptop).

## Structure

```
flake.nix                 # Flake inputs and outputs (flake-parts + import-tree)
assets/
  wallpaper.jpg           # Default wallpaper
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
    niri-void.nix         # Void laptop (eDP-1 @ 1.0 scale)
    gaming.nix            # Steam, Lutris, gamemode, mcpelauncher, xivlauncher
    kitty.nix             # Kitty terminal
    neovim.nix            # Neovim with LazyVim
    noctalia.nix          # Noctalia shell/launcher (bar, color schemes, wallpaper)
    pipewire.nix          # Audio (ALSA, PulseAudio, JACK, EasyEffects, mono mic)
    fileManager.nix       # Nautilus with dconf settings and Papirus-Dark icons
    llm.nix               # Ollama (ROCm) + Open WebUI
    insync.nix            # Insync Google Drive sync + inotify tuning
    airvpn.nix            # AirVPN via WireGuard (wg-quick, vpn-toggle script)
    tailscale.nix         # Tailscale with ts-toggle script
    comfyui.nix           # ComfyUI with PyTorch ROCm
  users/
    swin.nix              # hjem user file management (dotfiles)
    dotfiles/             # Managed dotfiles (kitty, btop, nvim, vscode, gtk)
```

## Hosts

### styx
Desktop (AMD Ryzen / RX 9070 XT). Dual monitors: Dell AW2724DM on DP-2 and Gigabyte M27Q — both at 2560x1440@143.

### void
Laptop (Intel). LUKS full-disk encryption. Built-in display (eDP-1) plus external monitor support.

## Deployment

```bash
# Deploy to styx
sudo nixos-rebuild switch --flake .#styx

# Deploy to void
sudo nixos-rebuild switch --flake .#void

# Check for errors without switching
nixos-rebuild build --flake .#styx
```

## Features

- **Multi-host:** Shared feature modules + host-specific configs; `import-tree` auto-loads all `.nix` files under `modules/`
- **Niri compositor:** Wayland WM with rounded corners, blur, opacity, focus ring, workspace keybinds
- **Theming:** Noctalia manages color schemes (Oxocarbon), wallpaper rotation, and GTK sync; `adw-gtk3-dark` with Oxocarbon libadwaita CSS overrides; Papirus-Dark icon theme
- **User files:** Per-user dotfiles managed declaratively via `hjem` (kitty, btop, nvim, vscode, GTK)
- **Gaming:** Steam, Lutris, gamemode, gamescope, Heroic, Minecraft Bedrock, XIV Launcher, lsfg-vk
- **Audio:** PipeWire with low-latency gaming support, EasyEffects, mono mic loopback
- **Browser:** Helium (privacy-focused Chromium) set as system default
- **Terminal:** Kitty
- **Editor:** Neovim with LazyVim
- **File manager:** Nautilus with gvfs, terminal integration, hidden files, list view; Oxocarbon GTK4 theming via `adw-gtk3-dark` + custom libadwaita CSS
- **Local AI:** Ollama with ROCm (RX 9070 XT) + Open WebUI at `localhost:8080`
- **Sync:** Insync (Google Drive) with inotify tuning for reliable background sync
- **VPN:** AirVPN via WireGuard (`vpn-toggle` script, NOPASSWD sudo); Tailscale with `ts-toggle` script; both shown in Noctalia bar
- **AI image gen:** ComfyUI with PyTorch ROCm (RX 9070 XT)
- **Utilities:** Docker, Sunshine/Moonlight, Flatpak, AppImage, NetworkManager
- **Security:** Firewall enabled on both hosts; Sunshine ports opened via `openFirewall`

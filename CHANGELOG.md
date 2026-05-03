# Changelog

All notable changes to this NixOS configuration are documented in this file.

## [1.7] - 2026-05-03

### Added

- **Helium browser:** added via `amaanq/helium-flake` community flake; sourced via `inputs.helium.packages` overlay
- **Flatpak:** `services.flatpak.enable = true`; Discord switched from nixpkgs package to Flatpak (`com.discordapp.Discord`) for Krisp support and working Tailscale audio
- **GitHub CLI:** `gh` added to system packages
- **Minecraft Bedrock:** `mcpelauncher-client` and `mcpelauncher-ui-qt` added to gaming.nix
- **EasyEffects:** added to pipewire.nix for mic noise suppression and volume boost
- **Mono mic loopback:** PipeWire `libpipewire-module-loopback` config creates a "Mono Mic" virtual source (captures FL channel only) to fix quiet stereo mic issue
- **Auto-login:** greetd `initial_session` added for passwordless login as swin
- **Second drive mount:** `fileSystems."/mnt/nvme2"` with UUID `eba90478-2582-4260-b65d-70cb4ffa1352`
- **Stylix theming:** `modules/features/theming.nix` — system-wide Tokyo Night Dark theme via `danth/stylix`; wallpaper stored at `assets/wallpaper.jpg`
- **Home Manager:** added as NixOS module via `nix-community/home-manager`; `modules/users/swin.nix` provides per-user home config with stylix home-manager integration
- **Tailscale routing fix:** `extraUpFlags = [ "--accept-routes=false" "--snat-subnet-routes=false" ]` to prevent Tailscale from routing local subnet traffic through tunnel (fixes slow DNS)

### Changed

- `Mod+D` keybind updated from `vesktop` → `flatpak run com.discordapp.Discord`
- Niri main monitor output corrected from `DP-1` → `DP-2` (Dell AW2724DM at 2560x1440@143.973)
- `networking.firewall.enable` set to `false`

### Removed

- `amdvlk` and `driversi686Linux.amdvlk` — removed from nixpkgs (RADV is the default AMD Vulkan driver)
- `discord` and `vesktop` system packages — replaced by Flatpak Discord

## [1.6] - 2026-04-29

### Added

- **New packages (styx):**
  - `davinci-resolve` — professional video editor (20.x; v21 pending version confirmation)
  - `insync` + `insync-nautilus` — Google Drive sync with Nautilus integration
  - `thunderbird` — email client
  - `gnome-calculator` — calculator
  - `inkscape` — vector graphics editor
  - `pinta` — raster image editor
  - `vlc` — media player

- **File manager:** switched from Dolphin to Nautilus
  - Removed KDE deps (dolphin, qtsvg, kio, kio-fuse, kio-extras, breeze-icons)
  - Added `nautilus`, `xdg-utils`, `services.gvfs` (network drive mounting), `programs.nautilus-open-any-terminal` (opens Kitty from context menu)

- **AMD GPU / DaVinci Resolve prep:**
  - `swin` user added to `render` and `video` groups
  - `rocmPackages.clr` added to `hardware.graphics.extraPackages` in llm.nix for ROCm OpenCL support

### Changed

- `Mod+E` keybind updated from `dolphin` to `nautilus`

## [1.5] - 2026-04-28

### Added

- **llm.nix module (styx only):** new `nixosModules.llm` feature module covering local AI
  - `services.ollama` with `pkgs.ollama-rocm` and `rocmOverrideGfx = "12.0.1"` for RX 9070 XT (RDNA4)
  - `services.open-webui` on `127.0.0.1:8080` — browser UI for local model interaction

### Changed

- Renamed `modules/features/ollama.nix` → `modules/features/llm.nix`; module ref updated from `nixosModules.ollama` → `nixosModules.llm`

## [1.4] - 2026-04-28

### Added

- **Docker:** `virtualisation.docker.enable = true`; `swin` added to `docker` group
- **Sunshine:** `services.sunshine` enabled as a user service with `autoStart` and `capSysAdmin` for virtual input/display support
- **New packages (styx):**
  - `epsonscan2` — Epson scanner
  - `freecad` — parametric 3D modeller
  - `google-earth-pro` — Google Earth
  - `loupe` — Wayland-native GTK4 image viewer
  - `nordpass` — password manager
  - `localsend` — local network file sharing
  - `pdfarranger` — PDF page organiser
  - `moonlight-qt` — game stream client (pairs with Sunshine)
  - `rusty-path-of-building` — Path of Building for PoE1 and PoE2 (added to gaming.nix)

## [1.3] - 2026-04-28

### Added

- **Niri input:** `warp-mouse-to-focus` — cursor warps to newly focused window
- **Niri input:** `hotkey-overlay.skip-at-startup` — suppresses hotkey overlay on login
- **Niri environment:** `ELECTRON_OZONE_PLATFORM_HINT=auto` — ensures Electron apps use native Wayland
- **XDG portal:** `xdg-desktop-portal-gtk` added for GTK file pickers; niri's own portal backend handles screen sharing

## [1.2] - 2026-04-27

### Added

- **Discord webapp:** Runs via Chrome (`--app=https://discord.com/app`) with `Mod+D` keybind
  - Added `--disable-features=WebRtcAllowInputVolumeAdjustment` to prevent Chrome WebRTC from altering mic volume

- **Niri window rules:**
  - Rounded corners (`geometry-corner-radius = 12`) on all windows
  - Catppuccin Mocha focus ring (`#CBA6F7` active, `#45475A` inactive)

- **New keybinds:**
  - `Mod+F` — Open Yazi terminal file manager in Kitty
  - `Mod+E` — Open Dolphin file manager
  - `Mod+semicolon` — Toggle wallpaper selector (Noctalia IPC)
  - `Mod+Shift+/` — Show hotkey overlay
  - `Mod+V` — Toggle window between floating and tiling

- **File manager improvements:**
  - Added `breeze-icons` and `xdg-utils` to fileManager.nix

- **Kitty:** Removed title bar (`hide_window_decorations yes`)

- **Neovim / LazyVim:**
  - Switched from nixvim to plain `pkgs.neovim` with LazyVim runtime dependencies
  - Added `tree-sitter` CLI, `trash-cli` for LazyVim health check compliance

### Changed

- `Mod+W` keybind reassigned from close-window to wallpaper — close-window moved to `Mod+W` (no change, kept as is)
- `Mod+semicolon` replaces the old wallpaper shortcut

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

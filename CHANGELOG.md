# Changelog

All notable changes to this NixOS configuration are documented in this file.

## [2.1] - 2026-05-15

### Added

- **airvpn.nix:** new module for AirVPN via WireGuard
  - `networking.wg-quick.interfaces.airvpn` with `autostart = false`; reads config from `/etc/wireguard/airvpn.conf`
  - `vpn-toggle` shell script: brings interface up/down by checking `ip link show airvpn`
  - NOPASSWD sudo rule for `wg-quick` so toggle works without password prompt

- **tailscale.nix:** Tailscale extracted from `configuration.nix` into its own feature module
  - `services.tailscale` with `permitCertUid = "swin"` and routing flags preserved (`--accept-routes=false`, `--snat-subnet-routes=false`)
  - `ts-toggle` shell script: brings Tailscale up/down by checking `ip link show tailscale0`
  - NOPASSWD sudo rule for `tailscale` binary

- **Noctalia widgets:** several new widgets added to `noctalia.json`
  - Tamagotchi widget
  - VPN status: two `CustomButton` widgets polling `ip link show airvpn` every 3s — shows `VPN` in primary color when up, error color when down; left-click runs `vpn-toggle`
  - Tailscale widget
  - GitHub feed widget
  - Bluetooth widget

### Changed

- **fileManager.nix:** switched back to Nautilus from Nemo; Thunar removed
  - `nemo-with-extensions` and `xfce.thunar` removed
  - `nautilus` + `nautilus-python` reinstated
  - `programs.nautilus-open-any-terminal` re-enabled with `terminal = "kitty"`
  - dconf settings updated: `org/nemo/preferences` and cinnamon terminal exec removed; `org/gnome/nautilus/preferences` (`show-hidden-files`, `default-folder-viewer = list-view`) restored

- **`Mod+F`:** `nemo` → `nautilus`

- **comfyui.nix:** PyTorch ROCm index URL bumped from `rocm6.4` → `rocm6.5`

- **configuration.nix:** inline `services.tailscale` block removed (now in `tailscale.nix`); `airvpn` and `tailscale` module imports added

## [2.0] - 2026-05-08

### Added

- **insync.nix:** new dedicated module consolidating all Insync-related config
  - inotify kernel tuning to fix sync stopping: `max_user_watches = 524288`, `max_user_instances = 512`, `max_queued_events = 131072`
  - `insync` and `insync-nautilus` packages moved here from host configs
  - Insync added to Niri `spawn-at-startup`

- **Nautilus settings via dconf:** icon theme, hidden files, list view configured declaratively
  - `programs.dconf` profile sets `org/gnome/desktop/interface icon-theme = Papirus-Dark`
  - `org/gnome/nautilus/preferences`: `show-hidden-files = true`, `default-folder-viewer = list-view`
  - `papirus-icon-theme` added to fileManager packages
  - GTK 3.0 and GTK 4.0 `settings.ini` added via hjem to enforce Papirus-Dark (bypasses dconf override issues)

- **Touchpad input (niri):** `tap`, `natural-scroll`, `accel-speed = 0.2` added to shared niri config

- **Thunderbird focus-or-launch keybind:** `Mod+E` now runs a script using `niri msg --json windows` to focus an existing Thunderbird window, or launches Thunderbird if none is open

- **Polkit agent:** `polkit-gnome-authentication-agent-1` added to Niri `spawn-at-startup`; `security.polkit.enable = true` added to void (was missing)

- **Firewall enabled** on both hosts; `services.sunshine.openFirewall = true` added to both to keep remote desktop functional

- **styx packages:** `teams-for-linux`, `rapidraw`, `impression`, `libreoffice`

- **void — fully configured** (was a skeleton after v1.0):
  - `theming`, `insync`, `swinHome` modules now imported
  - `nixpkgs-pinned` stable overlay added
  - Tailscale `extraUpFlags` synced with styx
  - SANE scanning (`hardware.sane` + `epsonscan2`)
  - Avahi with `nssmdns4` and `openFirewall`
  - AppImage support, Flatpak, Sunshine with `openFirewall`
  - User groups expanded to match styx (`render`, `video`, `scanner`, `lp`)
  - `security.polkit.enable = true`
  - Added packages: `gh`, `vscode-fhs`, `loupe`, `vlc`, `inkscape`, `pinta`, `davinci-resolve`, `impression`, `libreoffice`, `gnome-calculator`, `nethogs`, `linssid`, `moonlight-qt`, `lmstudio`

- **void hardware config:** updated from placeholder UUIDs to real hardware
  - Thunderbolt kernel module added
  - LUKS full-disk encryption configured
  - All partition UUIDs set to real values

- **hjem dotfiles:** btop.conf, all nvim config files, GTK settings added to `swin.nix`

- **Browser defaults on styx:** `xdg.mime.defaultApplications` and `BROWSER = "helium"` (was only set on void)

### Changed

- **Stylix removed** — replaced entirely by Noctalia color scheme management (`theming.nix` deleted, `stylix` input removed from `flake.nix` along with all transitive deps)
- **ROCm consolidated:** `rocmPackages.clr.icd` in `gaming.nix` upgraded to full `rocmPackages.clr`; duplicate `hardware.graphics.extraPackages` removed from `llm.nix`
- **Niri focus ring color:** `#CBA6F7` (Catppuccin purple) → `#7fc8ff` (blue)
- **`Mod+F`:** `kitty yazi` → `nautilus`
- **`Mod+E`:** `nautilus` → Thunderbird focus-or-launch
- **`Mod+A`:** `google-chrome-stable --app=...` → `helium --app=...`
- **GC retention:** 30 days → 14 days on both hosts
- **Shell alias** `n = "nvim"` moved into both host configs

### Removed

- `google-chrome` from both hosts — replaced by `helium`
- `discord`, `vesktop`, `google-earth-pro` from void
- Empty `users.users.swin.packages = []` from both hosts
- Stale `# --- Audio (see pipewire.nix) ---` and `# Misc` placeholder comments

## [1.9] - 2026-05-06

### Added

- **hjem:** replaced Home Manager with `feel-co/hjem` for user file management; dotfiles now live as plain files in `modules/users/dotfiles/` and are symlinked into place
  - `modules/users/dotfiles/kitty.conf` — kitty config as editable dotfile
  - `modules/users/dotfiles/vscode/settings.json` — VSCode settings as editable dotfile
  - `vscode-fhs` moved to system packages (was managed by HM)

- **Printer: Epson SC-T3160N:** configured via CUPS driverless IPP Everywhere
  - `services.avahi` enabled with `nssmdns4` and `openFirewall` for network printer/scanner discovery
  - `hardware.printers.ensurePrinters` declaratively adds `EPSON_SC_T3100_Series` with default tray set to `Rear`

- **Scanner: Epson DS-570W II:** `hardware.sane.enable = true` with `epsonscan2` as SANE backend; `swin` added to `scanner` and `lp` groups

- **Niri blur:** window blur working via `background-effect { blur true }` in global window rule; `prefer-no-csd` added to fix focus ring bleeding through transparent windows; `draw-border-with-background = false` in window rule
- **Niri opacity:** `opacity = 0.90` on global window rule for consistent window transparency
- **Niri keybind:** `Mod+O` — toggle focused window between transparent and opaque

### Changed

- `home-manager` input removed from `flake.nix`; replaced with `hjem` (`github:feel-co/hjem`)
- Config files reorganised with section comments (`# --- Boot ---`, `# --- Networking ---`, etc.) and packages grouped by category in both `styx` and `void` hosts
- Niri `blur` global settings: removed invalid `on` node; `saturation` removed (was causing purple tint)

### Removed

- Home Manager (`nix-community/home-manager`) — replaced by hjem

## [1.8] - 2026-05-05

### Added

- **Gigabyte M27Q monitor:** added EDID-based output config in `niri-styx.nix` (`GIGA-BYTE TECHNOLOGY CO., LTD. M27Q 21410B002170` on HDMI-A-1 @ 2560x1440@143.856); matches by full EDID string so it activates on any port
- **nvme3 drive:** formatted `/dev/nvme3n1p1` as ext4 (label `nvme3`) and mounted at `/mnt/nvme3` (UUID `3a71adec-87f1-430e-a3e3-9f1dd30e9b50`)
- **nvme0 drive:** formatted `/dev/nvme0n1p1` as ext4 (label `nvme0`) and mounted at `/mnt/nvme0` (UUID `6ab3631f-5d79-466e-a9fe-10aaddf7ce6e`)
- **AppImage support:** `programs.appimage.enable = true` + `programs.appimage.binfmt = true` — AppImages now run directly without wrappers

### Changed

- `Mod+B` keybind updated from `google-chrome-stable` → `helium`

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

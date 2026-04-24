# styx

My personal NixOS configuration, managed with flakes.

## Structure

```
flake.nix              # Flake inputs and outputs (flake-parts + import-tree)
modules/
  hosts/
    styx/              # Main host configuration
  features/
    gaming.nix         # Gaming setup (Steam, Lutris, gamemode)
    kitty.nix          # Kitty terminal, Catppuccin Mocha theme
    neovim.nix         # Neovim via nixvim, Catppuccin Mocha theme
    niri.nix           # Niri compositor config
    noctalia.nix       # Noctalia shell/launcher
    pipewire.nix       # Audio stack (ALSA, PulseAudio, JACK)
```

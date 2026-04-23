# styx

My personal NixOS configuration, managed with flakes.

## Structure

```
flake.nix              # Flake inputs and outputs (flake-parts + import-tree)
modules/
  hosts/
    styx/              # Main host configuration
  features/
    gaming.nix         # Gaming setup
    niri.nix           # Niri compositor config
    noctalia.nix       # Noctalia theme/config
```

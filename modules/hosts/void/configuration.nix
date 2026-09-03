{ self, inputs, ... }:
{

  flake.nixosModules.voidConfiguration =
    { pkgs, lib, ... }:
    {
      imports = [
        inputs.lix-module.nixosModules.lixFromNixpkgs
        self.nixosModules.voidHardware
        self.nixosModules.common # shared styx/void desktop foundation
        self.nixosModules.login
        self.nixosModules.hyprland
        self.nixosModules.webapps # URLs as frameless launcher entries (see myWebApps)
        self.nixosModules.gaming
        self.nixosModules.pipewire
        self.nixosModules.fileManager
        self.nixosModules.kitty
        self.nixosModules.neovim
        self.nixosModules.herdr # agent multiplexer (tmux-for-AI-agents)
        self.nixosModules.insync
        self.nixosModules.swinHome
        self.nixosModules.smb
        self.nixosModules.shell
        self.nixosModules.tailscale # tailscale + ts-toggle + NOPASSWD sudo rule
        self.nixosModules.davinciResolve # DaVinci Resolve 21 (free) + Blackmagic udev rules
        self.nixosModules.thunderbird # GTK_THEME-wrapped, same as styx
        self.nixosModules.bambuStudio # upstream AppImage; nixpkgs' is unfree/uncached (local source build)
      ];

      # --- Networking ---
      networking.hostName = "void";

      # --- Locale ---
      i18n.extraLocaleSettings = {
        LC_ADDRESS = "en_AU.UTF-8";
        LC_IDENTIFICATION = "en_AU.UTF-8";
        LC_MEASUREMENT = "en_AU.UTF-8";
        LC_MONETARY = "en_AU.UTF-8";
        LC_NAME = "en_AU.UTF-8";
        LC_NUMERIC = "en_AU.UTF-8";
        LC_PAPER = "en_AU.UTF-8";
        LC_TELEPHONE = "en_AU.UTF-8";
        LC_TIME = "en_AU.UTF-8";
      };

      # --- Bluetooth ---
      hardware.bluetooth.settings.Policy.JustWorksRepairing = "always";

      # --- Remote Access ---
      # (Sunshine comes from gaming.nix, which this host imports.)

      # --- Services ---
      services.upower.enable = true;

      # --- Hyprland ---
      myHyprland.idleLock = false; # disable auto-lock on idle
      myHyprland.autoSuspend = false; # suspend/resume doesn't survive cleanly on this hardware, forces relogin
      # SUPER + CTRL, not SUPER + ALT: wayscriber (common.nix) binds its own
      # toggles on mod + ALT + {D,S,L,F}, so an ALT-based mod here would double
      # up ALT in the chord and collide with those (and with the plain mod + D
      # Discord bind). CTRL only ever appears once elsewhere (mod + CTRL +
      # Print for OCR), which just collapses to itself, not a real collision.
      myHyprland.mod = "SUPER + CTRL"; # styx keeps plain SUPER; avoids collision when moonlighting into styx

      # --- Packages (void-only; shared set lives in common.nix) ---
      environment.systemPackages = with pkgs; [
        # Media & Creative
        komikku

        # Productivity
        obsidian

        # AI
        lmstudio
      ];

      system.stateVersion = "25.11";
    };
}

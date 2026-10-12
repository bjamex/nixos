# void — laptop. Everything shared with styx comes from common.nix; this file
# holds only what is void-specific.
{ self, ... }:
{
  flake.nixosModules.voidConfiguration =
    { pkgs, ... }:
    {
      imports = [
        self.nixosModules.voidHardware
        self.nixosModules.common # shared styx/void desktop foundation
      ];

      # --- Networking ---
      networking.hostName = "void";

      # --- Locale & Time ---
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

      # --- Hardware ---
      hardware.bluetooth.settings.Policy.JustWorksRepairing = "always";

      # --- Services ---
      services.upower.enable = true;

      # --- Desktop ---
      myHyprland = {
        idleLock = false;
        autoSuspend = false; # suspend/resume doesn't survive cleanly on this hardware, forces relogin
        # styx keeps plain SUPER; this avoids collisions when moonlighting into
        # styx. SUPER + CTRL, not SUPER + ALT: wayscriber binds its own toggles
        # on mod + ALT + {D,S,L,F}, so an ALT-based mod here would double up ALT
        # in the chord and collide with those (and with the plain mod + D
        # Discord bind). CTRL only ever appears once elsewhere (mod + CTRL +
        # Print for OCR), which just collapses to itself, not a real collision.
        mod = "SUPER + CTRL";
      };

      # --- Packages (void-only; shared set lives in common.nix) ---
      environment.systemPackages = with pkgs; [
        komikku # manga reader
        obsidian
        lmstudio
      ];

      system.stateVersion = "25.11";
    };
}

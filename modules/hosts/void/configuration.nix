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
        self.nixosModules.gaming
        self.nixosModules.pipewire
        self.nixosModules.fileManager
        self.nixosModules.kitty
        self.nixosModules.neovim
        self.nixosModules.insync
        self.nixosModules.swinHome
        self.nixosModules.smb
        self.nixosModules.shell
        self.nixosModules.tailscale # tailscale + ts-toggle + NOPASSWD sudo rule
        self.nixosModules.davinciResolve # DaVinci Resolve 21 (free) + Blackmagic udev rules
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

      # --- Packages (void-only; shared set lives in common.nix) ---
      environment.systemPackages = with pkgs; [
        # Media & Creative
        komikku

        # Internet & Communication
        thunderbird

        # Productivity
        obsidian

        # AI
        lmstudio
      ];

      system.stateVersion = "25.11";
    };
}

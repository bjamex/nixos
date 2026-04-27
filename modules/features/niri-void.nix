{ self, inputs, ... }: {
  flake.nixosModules.niriVoid = { config, pkgs, lib, ... }: {
    imports = [ self.nixosModules.niriBase ];

    perSystem = { pkgs, lib, self', ... }: {
      packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
        inherit pkgs;
        settings = self'.packages.niriCommonSettings // {
          # Void laptop with auto-detection for built-in + external monitors
          # Remove this section to use auto-detection for any connected monitors
          # Or define specific outputs here for your laptop screen:
          # outputs."eDP-1".mode = "1920x1080@60";  # Example laptop screen
          # outputs."HDMI-1".mode = "2560x1440@60"; # Example external monitor
        };
      };
    };
  };
}

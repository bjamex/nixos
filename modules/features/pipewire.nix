{ self, inputs, ... }: {

  flake.nixosModules.pipewire = {pkgs, ...}: {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    services.pipewire.wireplumber.extraConfig."99-volume-limit" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "~alsa.*"; } ];
          actions."update-props" = {
            "volume.limit" = 10.0;
            "api.alsa.soft-mixer" = true;
          };
        }
      ];
    };
};
}

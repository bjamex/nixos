{ self, inputs, ... }: {
  flake.nixosModules.fileManager = { config, pkgs, lib, ... }: {
    services.gvfs.enable = true;

    programs.nautilus-open-any-terminal = {
      enable = true;
      terminal = "kitty";
    };

    environment.systemPackages = with pkgs; [
      nautilus
      xdg-utils
    ];
  };
}

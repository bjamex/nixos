{ self, inputs, ... }: {
  flake.nixosModules.fileManager = { config, pkgs, lib, ... }: {
    services.gvfs.enable = true;

    programs.nautilus-open-any-terminal = {
      enable = true;
      terminal = "kitty";
    };

    programs.dconf.enable = true;
    programs.dconf.profiles.user.databases = [{
      settings = {
        "org/gnome/desktop/interface" = {
          icon-theme = "Papirus-Dark";
        };
        "org/gnome/nautilus/preferences" = {
          show-hidden-files = true;
          default-folder-viewer = "list-view";
        };
      };
    }];

    environment.systemPackages = with pkgs; [
      nautilus
      xdg-utils
      papirus-icon-theme
    ];
  };
}

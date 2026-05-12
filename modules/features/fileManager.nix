{ self, inputs, ... }: {
  flake.nixosModules.fileManager = { config, pkgs, lib, ... }: {
    services.gvfs.enable = true;

    # programs.nautilus-open-any-terminal = {
    #   enable = true;
    #   terminal = "kitty";
    # };

    programs.dconf.enable = true;
    programs.dconf.profiles.user.databases = [{
      settings = {
        "org/gnome/desktop/interface" = {
          icon-theme = "Papirus-Dark";
        };
        # "org/gnome/nautilus/preferences" = {
        #   show-hidden-files = true;
        #   default-folder-viewer = "list-view";
        # };
        "org/nemo/preferences" = {
          show-hidden-files = true;
          default-folder-viewer = "list-view";
        };
        "org/cinnamon/desktop/default-applications/terminal" = {
          exec = "kitty";
          exec-arg = "";
        };
      };
    }];

    environment.systemPackages = with pkgs; [
      # nautilus
      nemo-with-extensions
      xdg-utils
      papirus-icon-theme
    ];
  };
}

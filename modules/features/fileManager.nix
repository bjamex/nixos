{ self, inputs, ... }: {
  flake.nixosModules.fileManager = { config, pkgs, lib, ... }:
  let
    oxocarbon-gtk-theme = pkgs.stdenv.mkDerivation {
      pname = "oxocarbon-gtk-theme";
      version = "unstable-2023";
      src = pkgs.fetchzip {
        url = "https://git.sr.ht/~ved/oxocarbon-gtk/archive/0cf0eb35a927bffcb797db8a074ce240823d92de.tar.gz";
        hash = "sha256-URuoDJVRQ05S+u7mkz1EN5HWquhTC4OqY8MqAbl0crk=";
      };
      nativeBuildInputs = [ pkgs.dart-sass ];
      buildPhase = "sass scss:.";
      installPhase = ''
        install -d $out/share/themes/oxocarbon
        install -m 0644 index.theme $out/share/themes/oxocarbon/
        cp -r assets gtk-3.0 $out/share/themes/oxocarbon/
      '';
    };
  in {
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
          gtk-theme = "oxocarbon";
          color-scheme = "prefer-dark";
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
      oxocarbon-gtk-theme
    ];
  };
}

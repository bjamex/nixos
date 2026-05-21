{ self, inputs, ... }:
{
  flake.nixosModules.fileManager =
    {
      config,
      pkgs,
      lib,
      ...
    }:
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
    in
    {
      services.gvfs.enable = true;

      programs.nautilus-open-any-terminal = {
        enable = true;
        terminal = "kitty";
      };

      programs.dconf.enable = true;
      programs.dconf.profiles.user.databases = [
        {
          settings = {
            "org/gnome/desktop/interface" = {
              icon-theme = "Papirus-Dark";
              gtk-theme = "oxocarbon";
              color-scheme = "prefer-dark";
            };
            "org/gnome/nautilus/preferences" = {
              show-hidden-files = true;
              default-folder-viewer = "list-view";
            };
          };
        }
      ];

      programs.yazi = {
        enable = true;
        plugins = { inherit (pkgs.yaziPlugins) bookmarks; };
        initLua = pkgs.writeText "init.lua" ''
          require("bookmarks"):setup({
            persist = "all",
            desc_format = "full",
            notify = { enable = true, timeout = 1 },
          })
        '';
        settings.keymap.mgr.prepend_keymap = [
          {
            on = [ "m" ];
            run = "plugin bookmarks save";
            desc = "Save bookmark";
          }
          {
            on = [ "'" ];
            run = "plugin bookmarks jump";
            desc = "Jump to bookmark";
          }
          {
            on = [
              "b"
              "d"
            ];
            run = "plugin bookmarks delete";
            desc = "Delete bookmark";
          }
          {
            on = [
              "b"
              "D"
            ];
            run = "plugin bookmarks delete_all";
            desc = "Delete all bookmarks";
          }
        ];
      };

      environment.systemPackages = with pkgs; [
        nautilus
        nautilus-python
        xdg-utils
        papirus-icon-theme
        oxocarbon-gtk-theme
        sushi
      ];
    };
}

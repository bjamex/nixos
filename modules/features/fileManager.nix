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
      googleDriveMimeTypes = pkgs.stdenv.mkDerivation {
        name = "google-drive-mime-types";
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out/share/mime/packages
          cp ${pkgs.writeText "google-drive.xml" ''
            <?xml version="1.0" encoding="UTF-8"?>
            <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
              <mime-type type="application/x-google-sheets">
                <comment>Google Sheets</comment>
                <glob pattern="*.gdsheet"/>
              </mime-type>
              <mime-type type="application/x-google-doc">
                <comment>Google Doc</comment>
                <glob pattern="*.gdoc"/>
              </mime-type>
              <mime-type type="application/x-google-slides">
                <comment>Google Slides</comment>
                <glob pattern="*.gslides"/>
              </mime-type>
            </mime-info>
          ''} $out/share/mime/packages/google-drive.xml
        '';
      };

      gdocOpener = pkgs.makeDesktopItem {
        name = "gdoc-opener";
        desktopName = "Google Drive Opener";
        # Also handles application/json so yazi can route .gdsheet (detected as json) here.
        # Falls back to kitty+nvim for regular JSON files.
        exec = "${pkgs.writeShellScript "gdoc-open" ''
          url=$(${lib.getExe pkgs.jq} -r '.url // empty' "$1" 2>/dev/null)
          if [ -n "$url" ]; then
            helium "$url"
          else
            kitty nvim "$1"
          fi
        ''} %f";
        mimeTypes = [
          "application/x-google-sheets"
          "application/x-google-doc"
          "application/x-google-slides"
          "application/json"
        ];
        noDisplay = true;
      };

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
              gtk-theme = "adw-gtk3-dark";
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
        plugins = {
          inherit (pkgs.yaziPlugins) drag;
          bookmarks = pkgs.yaziPlugins.bookmarks.overrideAttrs (old: {
            postInstall = (old.postInstall or "") + ''
              substituteInPlace $out/main.lua \
                --replace-fail 'ya.mgr_emit' 'ya.emit'
            '';
          });
        };
        settings.yazi = {
          opener = {
            edit = [{ run = ''nvim "$@"'';        block = true;  desc = "nvim"; }];
            open = [{ run = ''xdg-open "$@"'';    orphan = true; desc = "xdg-open"; }];
          };
          open.prepend_rules = [
            { mime = "text/*";        use = "edit"; }
            { mime = "inode/x-empty"; use = "edit"; }
            { mime = "*/*";           use = "open"; }
          ];
        };
        initLua = pkgs.writeText "init.lua" ''
          require("bookmarks"):setup({
            persist = "all",
            desc_format = "full",
            notify = { enable = true, timeout = 1 },
          })
        '';
        settings.keymap.mgr.prepend_keymap = [
          {
            on = [ "O" ];
            run = ''shell --block 'handlr open --ask "$@"' '';
            desc = "Open with...";
          }
          {
            on = [ "<C-d>" ];
            run = "plugin drag";
            desc = "Drag selected files";
          }
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
        adw-gtk3
        sushi
        ripdrag
        googleDriveMimeTypes
        gdocOpener
        jq
        handlr-regex
      ];

      xdg.mime.defaultApplications = {
        "application/pdf"             = "com.github.xournalpp.xournalpp.desktop";
        "application/x-xopp"          = "com.github.xournalpp.xournalpp.desktop";
        "application/x-google-sheets" = "gdoc-opener.desktop";
        "application/x-google-doc"    = "gdoc-opener.desktop";
        "application/x-google-slides" = "gdoc-opener.desktop";
        "application/json"            = "gdoc-opener.desktop";
      };
    };
}

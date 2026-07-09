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

      gdocOpener = pkgs.makeDesktopItem {
        name = "gdoc-opener";
        desktopName = "Google Drive Opener";
        # Also handles application/json so yazi can route .gdsheet (detected as json) here.
        # Falls back to kitty+emacs for regular JSON files.
        exec = "${pkgs.writeShellScript "gdoc-open" ''
          url=$(${lib.getExe pkgs.jq} -r '.url // empty' "$1" 2>/dev/null)
          if [ -n "$url" ]; then
            helium "$url"
          else
            kitty ec "$1"
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
    in
    {
      services.gvfs.enable = true;

      programs.dconf.enable = true;
      programs.dconf.profiles.user.databases = [
        {
          settings = {
            "org/nemo/list-view" = {
              default-visible-columns = [ "name" "size" "mime_type" "date_modified" ];
              enable-folder-expansion = true;
            };
            "org/nemo/preferences" = {
              default-folder-viewer = "list-view";
              show-hidden-files = true;
              date-format-monospace = true;
              thumbnail-limit = lib.gvariant.mkUint64 (100 * 1024 * 1024);
            };
            "org/nemo/window-state" = {
              sidebar-bookmark-breakpoint = lib.gvariant.mkInt32 0;
              sidebar-width = lib.gvariant.mkInt32 180;
            };
            "org/nemo/preferences/menu-config" = {
              selection-menu-make-link = true;
              selection-menu-copy-to = true;
              selection-menu-move-to = true;
              background-menu-open-in-terminal = false;
              selection-menu-open-in-terminal = false;
            };
            "org/gnome/desktop/interface" = {
              icon-theme = "Papirus-Dark";
              gtk-theme = "oxocarbon";
              color-scheme = "prefer-dark";
            };
          };
        }
      ];

      programs.yazi = {
        enable = true;
        plugins = {
          inherit (pkgs.yaziPlugins) drag mediainfo;
          bookmarks = pkgs.yaziPlugins.bookmarks.overrideAttrs (old: {
            postInstall = (old.postInstall or "") + ''
              substituteInPlace $out/main.lua \
                --replace-fail 'ya.mgr_emit' 'ya.emit'
            '';
          });
        };
        settings.yazi = {
          # Route media through the mediainfo plugin: it renders the usual
          # image/video preview AND a metadata block in the preview pane.
          # Needs the `mediainfo` CLI on PATH (added to systemPackages below).
          plugin = {
            prepend_previewers = [
              { mime = "{audio,video,image}/*"; run = "mediainfo"; }
              { mime = "application/subrip"; run = "mediainfo"; }
            ];
            prepend_preloaders = [
              { mime = "{audio,video,image}/*"; run = "mediainfo"; }
              { mime = "application/subrip"; run = "mediainfo"; }
            ];
          };
          opener = {
            edit = [
              {
                run = "ec %s";
                block = true;
                desc = "emacs";
              }
            ];
            open = [
              {
                run = "xdg-open %s";
                orphan = true;
                desc = "xdg-open";
              }
            ];
          };
          open.prepend_rules = [
            {
              mime = "text/*";
              use = "edit";
            }
            {
              mime = "inode/x-empty";
              use = "edit";
            }
            {
              mime = "*/*";
              use = "open";
            }
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
            run = "shell --block 'handlr open --ask %s'";
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

      hjem.users.swin.files = {
        ".local/share/nemo/actions/open-in-terminal.nemo_action".text = ''
          [Nemo Action]
          Name=Open in Terminal
          Comment=Open kitty in this location
          Exec=kitty --directory %F
          Icon-Name=utilities-terminal
          Selection=Any
          Extensions=dir;
        '';
      };

      environment.systemPackages = with pkgs; [
        nautilus # default file manager again as of 2026-07-09 (crashes appear fixed)
        nemo-with-extensions
        nemo-fileroller
        file-roller
        webp-pixbuf-loader
        xdg-utils
        papirus-icon-theme
        adw-gtk3
        oxocarbon-gtk-theme
        ripdrag
        mediainfo
        googleDriveMimeTypes
        gdocOpener
        jq
        handlr-regex
      ];

      xdg.mime.defaultApplications = {
        "inode/directory"                    = "org.gnome.Nautilus.desktop";
        "application/zip"                    = "org.gnome.FileRoller.desktop";
        "application/vnd.rar"                = "org.gnome.FileRoller.desktop";
        "application/x-7z-compressed"        = "org.gnome.FileRoller.desktop";
        "application/x-bzip2-compressed-tar" = "org.gnome.FileRoller.desktop";
        "application/x-tar"                  = "org.gnome.FileRoller.desktop";
        "application/pdf" = "com.github.xournalpp.xournalpp.desktop";
        "application/x-xopp" = "com.github.xournalpp.xournalpp.desktop";
        "application/x-google-sheets" = "gdoc-opener.desktop";
        "application/x-google-doc" = "gdoc-opener.desktop";
        "application/x-google-slides" = "gdoc-opener.desktop";
        "application/json" = "gdoc-opener.desktop";
      };
    };
}

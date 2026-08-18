{ ... }:
{
  # Web apps — a URL opened as a frameless browser window, with a real desktop
  # entry so it turns up in the Noctalia launcher, plus an optional Hyprland
  # hotkey. This replaces the one-off `helium --app=https://gemini.google.com`
  # bind that used to live in hyprland.nix: that had no .desktop file, so the
  # app only existed if you remembered the keybind.
  flake.nixosModules.webapps =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.myWebApps;

      # Chromium's `--app=` drops the tab strip and omnibox, leaving just the page.
      appExec = app: "${cfg.browser} --app=${app.url}";

      desktopItems = lib.mapAttrsToList (
        key: app:
        pkgs.makeDesktopItem {
          name = "webapp-${key}";
          desktopName = app.name;
          exec = appExec app;
          icon = app.icon;
          categories = app.categories;
          # Without this the window comes up as a bare chrome-* class and the
          # dock/taskbar can't tie it back to this entry. Find the real value
          # with `hyprctl clients | grep class` once the app is open.
          startupWMClass = app.wmClass;
          terminal = false;
        }
      ) cfg.apps;

      hotkeyBinds = lib.mapAttrsToList (
        _: app: ''hl.bind(mod .. " + ${app.hotkey}", hl.dsp.exec_cmd("${appExec app}"))''
      ) (lib.filterAttrs (_: app: app.hotkey != null) cfg.apps);
    in
    {
      options.myWebApps = {
        browser = lib.mkOption {
          type = lib.types.str;
          default = "helium";
          description = ''
            Browser command used to launch web apps. Must understand Chromium's
            `--app=<url>` flag.
          '';
        };

        apps = lib.mkOption {
          default = { };
          description = "Web apps to install, keyed by a short slug.";
          type = lib.types.attrsOf (
            lib.types.submodule (
              { name, ... }:
              {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    default = name;
                    description = "Display name shown in the launcher.";
                  };

                  url = lib.mkOption {
                    type = lib.types.str;
                    description = "URL the app opens.";
                  };

                  icon = lib.mkOption {
                    type = lib.types.nullOr (lib.types.either lib.types.str lib.types.path);
                    default = null;
                    description = ''
                      Icon name from the current theme, or a path to an image. A
                      favicon can be pulled straight in, e.g.
                      `icon = pkgs.fetchurl { url = "..."; hash = "..."; };`
                    '';
                  };

                  hotkey = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = ''
                      Key bound under the Hyprland mod key — "A" gives SUPER+A,
                      "SHIFT + Y" gives SUPER+SHIFT+Y. Null for no bind.
                    '';
                  };

                  wmClass = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "StartupWMClass, matching the window back to this entry.";
                  };

                  categories = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ "Network" ];
                    description = "freedesktop categories for the desktop entry.";
                  };
                };
              }
            )
          );
        };
      };

      config = {
        environment.systemPackages = desktopItems;
        myHyprland.extraBindsLua = lib.concatStringsSep "\n" hotkeyBinds;

        # ── The apps ────────────────────────────────────────────────────────
        # Add one by dropping another attribute in here; the desktop entry (and
        # the hotkey, when given) follow automatically.
        myWebApps.apps = {
          claude = {
            name = "Claude";
            url = "https://claude.ai";
            hotkey = "A"; # SUPER+A, the slot Gemini used to hold
          };

          # Self-hosted on the Dockhand box; see project notes in sparkyfitness.
          sparkyfitness = {
            name = "SparkyFitness";
            url = "http://192.168.0.101:3004";
            hotkey = "S"; # SUPER+S (SUPER+SHIFT+S is the replay save, unaffected)
          };
        };
      };
    };
}

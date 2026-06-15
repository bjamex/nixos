{ self, inputs, ... }:
{
  # Zen Browser (Gecko/Firefox-based) wired from the zen-browser-flake. Kept as
  # an extensible feature module: switch the `variant`, bolt on enterprise
  # `extraPolicies`, or grow the `userChrome` theme over time. Ships with an
  # Oxocarbon chrome theme by default.
  #
  # We use the raw package (+ policies override) rather than the flake's
  # home-manager module, because this repo manages dotfiles with hjem. Theming
  # is delivered into a fixed, Nix-managed profile (~/.zen/oxocarbon); Zen still
  # creates its own databases inside that dir — only the theme files are managed.
  flake.nixosModules.zen =
    { pkgs, lib, config, ... }:
    let
      cfg = config.myZen;
      system = pkgs.stdenv.hostPlatform.system;

      basePolicies = {
        DisableAppUpdate = true; # Nix owns updates
        DisableTelemetry = true;
        Preferences = {
          # Required for userChrome.css (the Oxocarbon theme) to be applied.
          "toolkit.legacyUserProfileCustomizations.stylesheets" = {
            Value = true;
            Status = "locked";
          };
        };
      };

      zenPkg = inputs.zen-browser.packages.${system}.${cfg.variant}.override {
        extraPolicies = lib.recursiveUpdate basePolicies cfg.extraPolicies;
      };
    in
    {
      options.myZen = {
        variant = lib.mkOption {
          type = lib.types.enum [ "default" "beta" "twilight" "twilight-official" ];
          default = "default";
          description = "Which zen-browser-flake package variant to install ('default' tracks beta).";
        };

        extraPolicies = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = ''
            Extra Firefox enterprise policies, deep-merged over the defaults
            (telemetry off, Nix-managed updates, userChrome enabled). See
            https://mozilla.github.io/policy-templates/ for the schema.
          '';
        };

        userChrome = lib.mkOption {
          type = lib.types.lines;
          description = "Contents of the profile's chrome/userChrome.css.";
          default = ''
            /* ─── Oxocarbon theme for Zen Browser ─────────────────────────────
               Starter chrome theme — Zen's selectors shift between versions, so
               treat this as a base to expand. Palette: IBM Carbon (dark).      */
            :root {
              --oxo-base:    #161616;  /* window / deepest background        */
              --oxo-layer:   #262626;  /* toolbars, url bar                  */
              --oxo-layer2:  #393939;  /* borders, hover                     */
              --oxo-fg:      #f2f4f8;  /* primary text                       */
              --oxo-fg-dim:  #dde1e6;  /* secondary text                     */
              --oxo-accent:  #ee5396;  /* magenta-pink accent                */
              --oxo-accent2: #33b1ff;  /* blue accent                        */
            }

            /* Window, toolbox and toolbars */
            :root,
            #navigator-toolbox,
            #nav-bar,
            #TabsToolbar,
            #PersonalToolbar,
            #zen-appcontent-navbar-container {
              background-color: var(--oxo-base) !important;
              color: var(--oxo-fg) !important;
            }

            /* URL / search bar */
            #urlbar,
            #urlbar-background,
            #searchbar {
              background-color: var(--oxo-layer) !important;
              color: var(--oxo-fg) !important;
              border: 1px solid var(--oxo-layer2) !important;
            }
            #urlbar[focused="true"] > #urlbar-background {
              border-color: var(--oxo-accent) !important;
            }

            /* Tabs */
            .tabbrowser-tab .tab-content { color: var(--oxo-fg-dim) !important; }
            .tabbrowser-tab[selected] {
              background-color: var(--oxo-layer) !important;
            }
            .tabbrowser-tab[selected] .tab-content { color: var(--oxo-fg) !important; }

            /* Zen sidebar / workspace strip */
            #zen-sidebar-top-buttons,
            #zen-workspaces-button,
            #zen-sidebar-bottom-buttons {
              background-color: var(--oxo-base) !important;
            }
          '';
        };
      };

      config = {
        environment.systemPackages = [ zenPkg ];

        hjem.users.swin.files = {
          ".zen/profiles.ini".text = ''
            [Profile0]
            Name=oxocarbon
            IsRelative=1
            Path=oxocarbon
            Default=1

            [General]
            StartWithLastProfile=1
            Version=2
          '';
          ".zen/oxocarbon/chrome/userChrome.css".text = cfg.userChrome;
        };
      };
    };
}

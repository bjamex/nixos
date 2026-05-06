{ self, inputs, ... }: {
  flake.nixosModules.swinHome = { pkgs, ... }: {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.swin = {
      home.username = "swin";
      home.homeDirectory = "/home/swin";
      home.stateVersion = "25.11";

      gtk.gtk4.theme = null;

      # Disable Stylix theming for apps managed by noctalia live theming
      stylix.targets.kitty.enable = false;
      stylix.targets.btop.enable = false;

      programs.btop.enable = true;

      programs.vscode = {
        enable = true;
        package = pkgs.vscode-fhs;
        mutableExtensionsDir = true;
        profiles.default.extensions = with pkgs.vscode-extensions; [
          jnoortheen.nix-ide
          ms-vscode.cpptools
        ];
      };

      programs.kitty = {
        enable = true;
        extraConfig = "include ./themes/noctalia.conf";
        settings = {
          font_size = 12;
          hide_window_decorations = "yes";
          cursor_shape = "beam";
          confirm_os_window_close = 0;
          enable_audio_bell = "no";
          tab_bar_style = "separator";
          tab_separator = " | ";
          input_delay = 0;
          cursor_trail = 1;
          cursor_trail_decay = "0.07 0.15";
          sync_to_monitor = "no";
        };
      };
    };
  };
}

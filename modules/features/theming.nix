{ self, inputs, ... }: {
  flake.nixosModules.theming = { pkgs, ... }: {
    imports = [ inputs.stylix.nixosModules.stylix ];

    stylix.enable = true;
    stylix.image = self + /assets/wallpaper.jpg;
    stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";
    stylix.polarity = "dark";
  };
}

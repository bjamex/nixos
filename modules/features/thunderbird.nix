{ self, inputs, ... }: {
  flake.nixosModules.thunderbird = { pkgs, ... }: {
    environment.systemPackages = [
      (pkgs.symlinkJoin {
        name = "thunderbird";
        paths = [ pkgs.thunderbird ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = "wrapProgram $out/bin/thunderbird --set GTK_THEME Adwaita";
      })
    ];
  };
}

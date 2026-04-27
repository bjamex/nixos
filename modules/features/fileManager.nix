{ self, inputs, ... }: {
  flake.nixosModules.fileManager = { config, pkgs, lib, ... }: {
    environment.systemPackages = with pkgs; [
      kdePackages.dolphin
      kdePackages.qtsvg
      kdePackages.kio
      kdePackages.kio-fuse
      kdePackages.kio-extras
    ];
  };
}

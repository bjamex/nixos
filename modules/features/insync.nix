{ self, inputs, ... }: {
  flake.nixosModules.insync = { pkgs, ... }: {
    boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;

    environment.systemPackages = with pkgs; [
      insync
      insync-nautilus
    ];
  };
}

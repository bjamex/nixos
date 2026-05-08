{ self, inputs, ... }: {
  flake.nixosModules.insync = { pkgs, ... }: {
    boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;
    boot.kernel.sysctl."fs.inotify.max_user_instances" = 512;
    boot.kernel.sysctl."fs.inotify.max_queued_events" = 131072;

    environment.systemPackages = with pkgs; [
      insync
      insync-nautilus
    ];
  };
}

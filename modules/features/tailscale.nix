{ ... }: {
  flake.nixosModules.tailscale = { pkgs, ... }: {
    services.tailscale = {
      enable = true;
      permitCertUid = "swin";
      extraUpFlags = [
        "--accept-routes=false"
        "--snat-subnet-routes=false"
      ];
    };

    security.sudo.extraRules = [
      {
        users = [ "swin" ];
        commands = [
          {
            command = "${pkgs.tailscale}/bin/tailscale";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "ts-toggle" ''
        # The tailscale0 interface persists after `tailscale down`, so checking
        # for it always reports "up". Read the daemon's BackendState instead
        # ("Running" when connected, "Stopped"/"NeedsLogin" otherwise).
        state=$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null \
          | ${pkgs.jq}/bin/jq -r '.BackendState // "Stopped"')
        if [ "$state" = "Running" ]; then
          sudo ${pkgs.tailscale}/bin/tailscale down
        else
          sudo ${pkgs.tailscale}/bin/tailscale up --accept-routes=false --snat-subnet-routes=false
        fi
      '')
    ];
  };
}

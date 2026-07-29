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

    # Pinned to the exact argv ts-toggle uses: a rule naming the bare binary
    # accepts any arguments, which is the whole tailscale CLI (routes, exit
    # nodes, login state) password-free. `tailscale status` needs no sudo, so
    # only the two state-changing calls are listed. Keep the up-flags here in
    # sync with services.tailscale.extraUpFlags above — sudo matches the command
    # line exactly, so a flag change on one side breaks the toggle.
    security.sudo.extraRules = [
      {
        users = [ "swin" ];
        commands = [
          {
            command = "${pkgs.tailscale}/bin/tailscale up --accept-routes=false --snat-subnet-routes=false";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.tailscale}/bin/tailscale down";
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

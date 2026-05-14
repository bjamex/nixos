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
        if ip link show tailscale0 &>/dev/null; then
          sudo ${pkgs.tailscale}/bin/tailscale down
        else
          sudo ${pkgs.tailscale}/bin/tailscale up --accept-routes=false --snat-subnet-routes=false
        fi
      '')
    ];
  };
}

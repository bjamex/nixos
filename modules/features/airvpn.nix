{ ... }: {
  flake.nixosModules.airvpn = { pkgs, ... }: {
    networking.wg-quick.interfaces.airvpn = {
      autostart = false;
      configFile = "/etc/wireguard/airvpn.conf";
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "vpn-toggle" ''
        if ip link show airvpn &>/dev/null; then
          sudo ${pkgs.wireguard-tools}/bin/wg-quick down airvpn
        else
          sudo ${pkgs.wireguard-tools}/bin/wg-quick up airvpn
        fi
      '')
    ];

    security.sudo.extraRules = [
      {
        users = [ "swin" ];
        commands = [
          {
            command = "${pkgs.wireguard-tools}/bin/wg-quick";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}

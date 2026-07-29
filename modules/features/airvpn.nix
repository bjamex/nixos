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

    # Pinned to the exact argv vpn-toggle uses. A rule naming the bare binary
    # accepts *any* arguments, and `wg-quick up <path>` runs that config's
    # PreUp/PostUp hooks as root — so an unrestricted NOPASSWD rule here hands
    # password-free root to anything already running as swin.
    security.sudo.extraRules = [
      {
        users = [ "swin" ];
        commands = [
          {
            command = "${pkgs.wireguard-tools}/bin/wg-quick up airvpn";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.wireguard-tools}/bin/wg-quick down airvpn";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}

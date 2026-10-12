# AirVPN over WireGuard, off by default. `vpn-toggle` (bound to the Noctalia
# bar's VPN button) brings the tunnel up and down via a narrow NOPASSWD rule.
# The config itself lives at /etc/wireguard/airvpn.conf, outside the repo.
{ ... }:
{
  flake.nixosModules.airvpn =
    { pkgs, ... }:
    let
      wg-quick = "${pkgs.wireguard-tools}/bin/wg-quick";
    in
    {
      networking.wg-quick.interfaces.airvpn = {
        autostart = false;
        configFile = "/etc/wireguard/airvpn.conf";
      };

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "vpn-toggle" ''
          if ip link show airvpn &>/dev/null; then
            sudo ${wg-quick} down airvpn
          else
            sudo ${wg-quick} up airvpn
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
              command = "${wg-quick} up airvpn";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${wg-quick} down airvpn";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };
}

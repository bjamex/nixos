# Tailscale on every host. `ts-toggle` (bound to the Noctalia bar's Tailscale
# button) flips the connection via a narrow NOPASSWD rule.
{ ... }:
{
  flake.nixosModules.tailscale =
    { pkgs, ... }:
    let
      tailscale = "${pkgs.tailscale}/bin/tailscale";
    in
    {
      services.tailscale = {
        enable = true;
        permitCertUid = "swin";
        extraUpFlags = [
          "--accept-routes=false"
          "--snat-subnet-routes=false"
        ];
      };

      environment.systemPackages = [
        (pkgs.writeShellScriptBin "ts-toggle" ''
          # The tailscale0 interface persists after `tailscale down`, so checking
          # for it always reports "up". Read the daemon's BackendState instead
          # ("Running" when connected, "Stopped"/"NeedsLogin" otherwise).
          state=$(${tailscale} status --json 2>/dev/null \
            | ${pkgs.jq}/bin/jq -r '.BackendState // "Stopped"')
          if [ "$state" = "Running" ]; then
            sudo ${tailscale} down
          else
            sudo ${tailscale} up --accept-routes=false --snat-subnet-routes=false
          fi
        '')
      ];

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
              command = "${tailscale} up --accept-routes=false --snat-subnet-routes=false";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${tailscale} down";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };
}

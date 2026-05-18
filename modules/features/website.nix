{ self, inputs, ... }: {

  flake.nixosModules.website = { ... }: {
    services.nginx = {
      enable = true;
      virtualHosts."localhost" = {
        listen = [ { addr = "0.0.0.0"; port = 6969; } ];
        root = "/var/www/html";
        locations."/".index = "index.html";
      };
    };

    networking.firewall.allowedTCPPorts = [ 6969 ];
  };
}

{ config, pkgs, ... }:

{
  ### Nextcloud
  environment.etc."nextcloud-admin-pass".text = "nixos";
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud31;
    hostName = "localhost";
    settings = {
      trusted_domains = [
        "localhost"
        "192.168.1.127"
      ];
    };
    config = {
      adminpassFile = "/etc/nextcloud-admin-pass";
      dbtype = "sqlite";
    };
  };

  ### Allow http/s firewall ports
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}

{ lib, config, pkgs, ... }:

{
 ### Nextcloud
 environment.etc."nextcloud-admin-pass".text = "PWD";
 services.nextcloud = {
   enable = true;
   package = pkgs.nextcloud31;
   hostName = "192.168.1.127";
   config.adminpassFile = "/etc/nextcloud-admin-pass";
   config.dbtype = "sqlite";
 };
 
 ### Allow http/s firewall ports
 networking.firewall.allowedTCPPorts = lib.mkDefault [ 80 443 ];
}

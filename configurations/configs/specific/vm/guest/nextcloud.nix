{ config, pkgs, ... }:

{
 ### Nextcloud
 environment.etc."nextcloud-admin-pass".text = "nixos";
 services.nextcloud = {
   enable = true;
   hostName = "nixos-nextcloud";
   package = pkgs.nextcloud31;
   config = {
     adminpassFile = "/etc/nextcloud-admin-pass";
     dbtype = "sqlite";
   };
 };
}

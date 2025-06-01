{ config, pkgs, ... }:

{
 ### Nextcloud
 environment.etc."nextcloud-admin-pass".text = "nixos";
 services.nextcloud = {
   enable = true;
   hostName = "nixos-nextcloud";
   package = pkgs.nextcloud31;
   configureRedis = true;
   config = {
     adminpassFile = "/etc/nextcloud-admin-pass";
     dbtype = "pgsql";
     dbuser = "nextcloud";
     dbhost = "/run/postgresql";
     dbname = "nextcloud";
   };
 };
 
 ### Setup postgresql (for nextcloud)
 services.postgresql = {
   enable = true;
   ensureDatabases = [ "nextcloud" ];
   ### Temporary passwd (sops-nix needed later)
   initialScript = pkgs.writeText "nextcloud-init.sql" ''
     CREATE ROLE nextcloud WITH LOGIN PASSWORD 'motdepasse';
     CREATE DATABASE nextcloud WITH OWNER nextcloud;
     GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextcloud;
   '';
   ensureUsers = [
     {
       name = "nextcloud";
       ensurePermissions."DATABASE nextcloud" = "ALL PRIVILEGES";
     }
   ];
 };
 
 # ensure that postgres is running *before* running the setup
 systemd.services."nextcloud-setup" = {
   requires = ["postgresql.service"];
   after = ["postgresql.service"];
 };
}

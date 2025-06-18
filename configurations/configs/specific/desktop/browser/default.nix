{ config, pkgs, ... }:

{
 ### Import all expr for the browser
 imports = [
   ./firefox
   ./zen-browser
 ];

 ### Create directory with systemd user service
 systemd.user.services.create-firejail-browser-dir = {
   enable = true;
   description = "Create Firejail private directory";
   serviceConfig = {
     Type = "oneshot";
     ExecStart = "${pkgs.coreutils}/bin/mkdir -p %h/private";
   };
   wantedBy = [ "graphical.target" ];
 };

 ### Enable Firejail (common config)
 programs.firejail.enable = true;
}

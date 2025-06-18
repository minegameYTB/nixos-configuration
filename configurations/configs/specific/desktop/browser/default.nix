{ config, pkgs, ... }:

{
 ### Import all expr for the browser
 imports = [
   ./firefox
   ./zen-browser
 ];

 ### Enable Firejail (common config)
 programs.firejail.enable = true;
}

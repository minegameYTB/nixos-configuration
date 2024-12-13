{ config, pkgs, ... }:

{
 ### Systemd-boot
 boot.loader = {
   systemd-boot = {
     enable = true;
     configurationLimit = 10;
   };
   efi.canTouchEfiVariables = true;
 };  
}

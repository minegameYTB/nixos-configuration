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
 
 ### Use efi partitionment
 fileSystems."/boot" = { 
   device = "/dev/disk/by-label/EFI";
   fsType = "vfat";
   options = [ "fmask=0077" "dmask=0077" ];
 };
}

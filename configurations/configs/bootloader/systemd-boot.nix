{ config, pkgs, ... }:

{
 ### Systemd-boot
 boot.loader = {
   systemd-boot = {
     enable = true;
     configurationLimit = 10;
     
     ### Enable memtest86+
     extraFiles = {
       "efi/memtest86/memtest.efi" = "${pkgs.memtest86plus}/memtest.efi";
     };
     extraEntries = {
       "memtest86.conf" = ''
         title Memtest86+
         efi /efi/memtest86/memtest.efi
         sort-key z_memtest
       '';
     };
     memtest86.enable = true;
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

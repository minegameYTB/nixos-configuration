{ config, ... }:

{ 
 ### Add efi specific mountpoint
 fileSystems."/boot/efi" = {
   device = "/dev/disk/by-label/EFI";
   fsType = "vfat";
   options = [ "fmask=0022" "dmask=0022" ];
 };

 boot.loader = {
   grub = {
     efiSupport = true;
     device = "nodev";
   };
   ### Use /boot/efi as a mountpoint for grub2
   efi.efiSysMountPoint = "/boot/efi";
 };
}

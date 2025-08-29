{ config, ... }:

{ 
 ### Import efi mountpoint expression
 imports = [ ../efi-mountpoint.nix ];
 
 boot.loader = {
   grub = {
     efiSupport = true;
     device = "nodev";
   };
   ### Use /boot/efi as a mountpoint for grub2
   efi.efiSysMountPoint = "/boot/efi";
 };
}

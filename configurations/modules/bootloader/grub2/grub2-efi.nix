{ config, pkgs, ... }:

{
 ### Import grub2 common settings expression
 imports = [ ../grub2.nix ];
 

 boot.loader = {
   grub = {
     efiSupport = true;
     device = "nodev";
   };
   ### Use /boot/efi as a mountpoint for grub2
   efi.efiSysMountPoint = "/boot/efi";
 };
}

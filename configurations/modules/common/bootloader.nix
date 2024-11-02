{ config, pkgs, ... }:

{
 # Bootloader
 boot.loader = {
   grub.enable = true;
   grub.device = "nodev";
   grub.efiSupport = true;
   grub.configurationLimit = 10;
   efi.efiSysMountPoint = "/boot/efi";
 };  
}

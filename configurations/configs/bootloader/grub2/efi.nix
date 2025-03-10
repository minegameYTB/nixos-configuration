{ config, ... }:

{
 ### Import grub2 efi settings expression
 imports = [ ./grub2-efi.nix ];

 ### Add efi specific mountpoint
 fileSystems."/boot/efi" = {
   device = "/dev/disk/by-label/EFI";
   fsType = "vfat";
   options = [ "fmask=0022" "dmask=0022" ];
 };
}

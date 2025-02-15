{ ... }:

{
 ### Import nix expression for vm no-gui (efi)
 imports = 
   [ ./base-profile/vm-no-gui-profile.nix  ### Import profile
     ../configurations/modules/bootloader/grub2/bios-novirtio.nix
   ];
}

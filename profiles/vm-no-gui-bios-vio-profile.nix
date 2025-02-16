{ ... }:

{
 ### Import nix expression for vm no-gui (efi)
 imports = 
   [ ./base-profiles/vm-no-gui-profile.nix  ### Import profile
     ../configurations/modules/bootloader/grub2/bios-virtio.nix
   ];
}

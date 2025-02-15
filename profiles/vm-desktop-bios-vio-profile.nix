{ ... }:

{
 ### Import nix expression for vm-desktop (efi)
 imports = 
   [ ./base-profiles/vm-desktop-profile.nix  ### Import profile
      ../configurations/modules/bootloader/grub2/bios-virtio.nix
   ];
}

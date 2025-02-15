{ ... }:

{
 ### Import nix expression for vm-desktop (efi)
 imports = 
   [ ./base-profile/vm-desktop-profile.nix  ### Import profile
     ../configurations/modules/bootloader/systemd-boot.nix
   ];
}

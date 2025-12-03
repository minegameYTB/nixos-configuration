{ ... }:

{
  ### Import nix expression for vm-desktop (efi)
  imports = [
    ./base-profiles/vm-desktop-profile.nix # Import profile
    ../configurations/configs/bootloader/systemd-boot.nix
  ];
}

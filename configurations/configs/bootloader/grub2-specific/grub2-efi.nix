{ config, ... }:

{
  ### Import efi mountpoint expression
  imports = [ ../efi-mountpoint.nix ];

  boot.loader = {
    grub = {
      efiSupport = true;
      device = "nodev";
    };
    efi = {
      ### Use /boot/efi as a mountpoint for grub2
      efiSysMountPoint = "/boot/efi";

      ### Enable EFI editable variable
      canTouchEfiVariables = true;
    };
  };
}

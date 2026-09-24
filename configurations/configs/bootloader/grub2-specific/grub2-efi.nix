{ ... }:

{
  imports = [
    ../grub2.nix
    ../efi-mountpoint.nix
  ];

  boot.loader = {
    grub = {
      efiSupport = true;
      device = "nodev";
    };
    efi = {
      efiSysMountPoint = "/boot";
      canTouchEfiVariables = true;
    };
  };
}

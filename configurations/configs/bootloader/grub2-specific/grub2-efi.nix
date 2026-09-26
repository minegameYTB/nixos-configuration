{ config, ... }:

{
  imports = [
    ../grub2.nix
    ../efi-mountpoint.nix
  ];

  boot.loader = {
    grub = {
      efiSupport = true;
      device = "nodev";
      zfsSupport = config.boot.zfs.enabled;
    };
    efi = {
      efiSysMountPoint = "/boot";
      canTouchEfiVariables = true;
    };
  };
}

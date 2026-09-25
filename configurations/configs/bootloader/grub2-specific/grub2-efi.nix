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
      zfsSupport = if (config.fileSystems."/".fsType == "zfs") then true else false;
    };
    efi = {
      efiSysMountPoint = "/boot";
      canTouchEfiVariables = true;
    };
  };
}

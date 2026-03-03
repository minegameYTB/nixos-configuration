{ config, pkgs, ... }:

{
  ### Import btrfs filesystem (luksFS is used as a container with btrfs inside)
  imports = [ ../btrfs ];

  ### Luks specific settings
  # Settings for luks
  boot.initrd.luks.devices."luks-encrypted" = {
    device = "/dev/disk/by-partlabel/disk-main-luks";

    # For keyFile, make sure to change this path (and user used) in case of a fork and using luks encryption
    keyFile = "/dev/disk/by-id/mmc-APPSD_0x00000354-part1";
    keyFileSize = 4096;
  };
}

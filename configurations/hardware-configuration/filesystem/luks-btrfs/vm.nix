{ config, pkgs, ... }:

{
  ### Include original luks partitionning and override keyFile option
  imports = [ ./default.nix ];

  boot.initrd.luks.devices."luks-encrypted" = {
    keyFile = "/dev/disk/by-id/mmc-APPSD_0x00000354-part1";
  };
}

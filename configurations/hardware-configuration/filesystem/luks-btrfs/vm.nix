{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Include original luks partitioning and override keyFile option
  imports = [ ./default.nix ];

  boot.initrd.luks.devices."luks-encrypted" = {
    keyFile = "/dev/vdb1";
  };
}

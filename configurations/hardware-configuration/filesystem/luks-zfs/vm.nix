{
  lib,
  config,
  pkgs,
  ...
}:

{
  imports = [ ./default.nix ];

  boot.initrd.luks.devices."luks-encrypted" = {
    keyFile = "/dev/vdb1";
  };
}

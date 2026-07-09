{ config, lib, ... }:

{
  ### Enable swap devices when this expression is imported
  ### Swapfiles are incompatible with ZFS — skip when root is on ZFS
  swapDevices = lib.mkIf (config.fileSystems."/".fsType != "zfs") [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024;
    }
  ];
}

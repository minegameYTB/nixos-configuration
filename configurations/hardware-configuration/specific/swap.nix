{ config, lib, ... }:

{
  swapDevices = lib.mkIf (config.fileSystems."/".fsType != "zfs") [
    {
      device = "/var/lib/swapfile";
      size = 8 * 1024;
    }
  ];
}

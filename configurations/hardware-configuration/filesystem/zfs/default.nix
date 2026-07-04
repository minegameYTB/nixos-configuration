{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ../zfs-common.nix ];

  ### Persistent swap zvol (created by disko)
  swapDevices = [
    { device = "/dev/zvol/zroot/swap"; }
  ];

  ### Disko-generated mountpoints (zroot datasets)
  fileSystems."/" = {
    device = "zroot/ROOT/nixos";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "zroot/home";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "zroot/nix";
    fsType = "zfs";
  };

  fileSystems."/var/log" = {
    device = "zroot/var/log";
    fsType = "zfs";
  };

  fileSystems."/var/cache" = {
    device = "zroot/var/cache";
    fsType = "zfs";
  };
}

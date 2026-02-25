{
  lib,
  config,
  pkgs,
  ...
}:

{
  fileSystems."/" = {
    device = "zroot";
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

  fileSystems."/nix/var" = {
    device = "zroot/nix/var";
    fsType = "zfs";
  };

  fileSystems."/var" = {
    device = "zroot/var";
    fsType = "zfs";
  };

  fileSystems."/var/cache" = {
    device = "zroot/var/cache";
    fsType = "zfs";
  };

  fileSystems."/var/log" = {
    device = "zroot/var/log";
    fsType = "zfs";
  };

  fileSystems."/var/tmp" = {
    device = "zroot/var/tmp";
    fsType = "zfs";
  };

  ### Enable ZFS
  services.zfs.trim.enable = true;

  ### Add supported file systems
  boot.supportedFilesystems = {
    zfs = true;
    btrfs = true;
    ext4 = true;
  };

  ### ZFS package
  boot.zfs.package = pkgs.zfs;

  ### For zfs import
  networking.hostId = "b08dfa60";

  swapDevices = [ ];
}

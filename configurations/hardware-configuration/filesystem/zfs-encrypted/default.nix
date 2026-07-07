{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ../zfs-common.nix ];

  ### Load the MMC/SD block driver in initrd so the key device is available
  boot.initrd.kernelModules = [
    "mmc_block"
  ];

  ### Enable ZFS encryption key loading at boot
  ### Datasets have keylocation pointing to the raw key device (set by disko)
  boot.zfs.requestEncryptionCredentials = true;

  ### ZFS pool is directly on the partition — scan by partuuid
  boot.zfs.devNodes = "/dev/disk/by-partuuid";

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

  fileSystems."/var/db" = {
    device = "zroot/var/db";
    fsType = "zfs";
  };

  fileSystems."/var/lib" = {
    device = "zroot/var/lib";
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

  fileSystems."/var/spool" = {
    device = "zroot/var/spool";
    fsType = "zfs";
  };

  fileSystems."/var/tmp" = {
    device = "zroot/var/tmp";
    fsType = "zfs";
  };

  fileSystems."/var/crash" = {
    device = "zroot/var/crash";
    fsType = "zfs";
  };

  fileSystems."/var/lib/libvirt" = lib.mkIf config.virtualisation.libvirtd.enable {
    device = "zroot/var/lib/libvirt";
    fsType = "zfs";
  };
}

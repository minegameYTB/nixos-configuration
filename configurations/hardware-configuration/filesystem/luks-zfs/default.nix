{
  lib,
  config,
  ...
}:

{
  imports = [ ../zfs-common.nix ];

  ### Persistent swap zvol (created by disko)
  swapDevices = [
    { device = "/dev/zvol/zroot/swap"; }
  ];

  ### ZFS pool is inside the LUKS mapper — scan /dev/mapper/
  boot.zfs.devNodes = "/dev/mapper";

  ### LUKS initrd setup for encrypted ZFS
  boot.initrd.kernelModules = [
    "mmc_block"
  ];

  boot.initrd.luks.devices."luks-encrypted" = {
    device = "/dev/disk/by-partlabel/disk-main-luks";
    keyFile = lib.mkDefault "/dev/disk/by-id/mmc-APPSD_0x00000354-part1";
    keyFileSize = 4096;
    keyFileTimeout = 5;
  };

  ### ZFS datasets on LUKS (mountpoints are inherited from pool)
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

  fileSystems."/var/lib/libvirt" = lib.mkIf config.virtualisation.libvirtd.enable {
    device = "zroot/var/lib/libvirt";
    fsType = "zfs";
  };
}

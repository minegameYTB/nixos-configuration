{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ../zfs-common.nix ];

  ### No encryption on datasets — skip zfs load-key -a in initrd (speeds boot)
  boot.zfs.requestEncryptionCredentials = false;

  ### ZFS pool is directly on the partition — scan by partuuid
  boot.zfs.devNodes = "/dev/disk/by-partuuid";

  ### Disko-generated mountpoints (zroot datasets)
  fileSystems."/" = {
    device = "zroot/ROOT/nixos";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "zroot/home";
    fsType = "zfs";
    options = [
      "nodev"
      "nosuid"
    ];
  };

  fileSystems."/nix" = {
    device = "zroot/nix";
    fsType = "zfs";
  };

  fileSystems."/nix/var" = {
    device = "zroot/nix/var";
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
    options = [
      "nodev"
      "noexec"
      "nosuid"
    ];
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
    options = [ "nodev" ];
  };

  fileSystems."/nix/var/nix" = {
    device = "zroot/nix/var/nix";
    fsType = "zfs";
  };

  fileSystems."/nix/var/nix/db" = {
    device = "zroot/nix/var/nix/db";
    fsType = "zfs";
  };

  fileSystems."/var/lib/libvirt" = lib.mkIf config.virtualisation.libvirtd.enable {
    device = "zroot/var/lib/libvirt";
    fsType = "zfs";
  };

  fileSystems."/var/lib/libvirt/images" = lib.mkIf config.virtualisation.libvirtd.enable {
    device = "zroot/var/lib/libvirt/images";
    fsType = "zfs";
  };
}

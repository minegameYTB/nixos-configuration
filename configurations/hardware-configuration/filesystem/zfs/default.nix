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

  ### ZFS pool is directly on the partition — scan only ZFS member partitions
  ### via the by-fs namespace (see doc/udev-by-fs.md). The by-fs links exist
  ### in the initrd thanks to boot.initrd.services.udev.rules (disk-symlinks.nix).
  boot.zfs.devNodes = "/dev/disk/by-fs/zfs_member/fs-uuid";

  ### Disko-generated mountpoints (zroot datasets)
  fileSystems."/" = {
    device = "zroot/ROOT/nixos";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "zroot/USERDATA/home";
    fsType = "zfs";
    options = [ "nosuid" ];
  };

  fileSystems."/root" = {
    device = "zroot/USERDATA/root";
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

  fileSystems."/var/lib/AccountsService" = lib.mkIf config.services.accounts-daemon.enable {
    device = "zroot/var/lib/AccountsService";
    fsType = "zfs";
  };

  fileSystems."/var/lib/NetworkManager" = lib.mkIf config.networking.networkmanager.enable {
    device = "zroot/var/lib/NetworkManager";
    fsType = "zfs";
  };

  fileSystems."/var/lib/docker" = lib.mkIf config.virtualisation.docker.enable {
    device = "zroot/var/lib/docker";
    fsType = "zfs";
  };

  fileSystems."/var/lib/flatpak" = lib.mkIf config.services.flatpak.enable {
    device = "zroot/var/lib/flatpak";
    fsType = "zfs";
  };

  fileSystems."/var/lib/fwupd" = lib.mkIf config.services.fwupd.enable {
    device = "zroot/var/lib/fwupd";
    fsType = "zfs";
  };
}

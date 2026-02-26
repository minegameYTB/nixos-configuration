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

  swapDevices = [ ];

  ### Add supported file systems
  boot.supportedFilesystems = {
    zfs = true;
    btrfs = true;
    ext4 = true;
  };

  ### ZFS specific options
  boot.zfs = {
    removeLinuxDRM = true;
    forceImportRoot = true;
    devNodes = "/dev/disk/by-partlabel/disk-main-zfs";
    package = pkgs.zfs;
  };

  services.zfs = {
    autoScrub = {
      enable = true;
      pools = [ "zroot" ];
      interval = "monthly";
    };
    autoSnapshot = {
      enable = true;
      weekly = 8;
      monthly = 0;
      frequent = 0;
      hourly = 0;
      daily = 0;
    };
    trim = {
      enable = true;
      interval = "weekly";
    };
  };

  ### For zfs import
  networking.hostId = "b08dfa60";
}

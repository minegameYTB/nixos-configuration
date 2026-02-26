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
    forceImportRoot = true;
    devNodes = "/dev/disk/by-partlabel";
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

  ### Fix mount boot
  boot.initrd = {
    systemd.services.wait-for-disks = {
      description = "Wait for disks to settle (udev)";
      wantedBy = [ "initrd-fs.target" ];
      before = [
        "zfs-import-zroot.service"
        "sysroot.mount"
      ];
      unitConfig = {
        DefaultDependencies = false;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.systemd}/bin/udevadm settle --timeout=120";
        TimeoutStartSec = 150;
      };
    };
    systemd.services."zfs-import-zroot" = {
      after = [ "wait-for-disks.service" ];
      wants = [ "wait-for-disks.service" ];
      serviceConfig.TimeoutStartSec = 120;
    };
    systemd.services."zfs-mount" = {
      after = [
        "zfs-import-zroot.service"
        "wait-for-disks.service"
      ];
      requires = [ "zfs-import-zroot.service" ];
      serviceConfig = {
        TimeoutStartSec = 180;
      };
    };
    systemd.mounts = [
      {
        where = "/sysroot";
        what = "zroot";
        type = "zfs";
        options = [
          "zfsutil"
          "noatime"
          "X-mount.mkdir"
        ];
        wantedBy = [ "initrd-fs.target" ];
        before = [ "initrd-fs.target" ];
        requires = [
          "zfs-import-zroot.service"
          "zfs-mount.service"
        ];
        after = [
          "zfs-import-zroot.service"
          "zfs-mount.service"
          "wait-for-disks.service"
        ];
      }
    ];
  };
}

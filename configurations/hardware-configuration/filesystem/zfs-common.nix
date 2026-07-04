{ config, ... }:

{
  ### Enable ZFS support
  boot = {
    supportedFilesystems = {
      zfs = true;
      ext4 = true;
    };
    zfs.enabled = true;
    kernelParams = [ "nohibernate" ];
  };

  ### ZFS auto-scrub
  services.zfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  ### ZFS auto-trim
  services.zfs.trim = {
    enable = true;
    interval = "monthly";
  };
}

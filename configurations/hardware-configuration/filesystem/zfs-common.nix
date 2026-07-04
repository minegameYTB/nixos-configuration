{ config, lib, ... }:

{
  ### Enable ZFS support
  boot.supportedFilesystems = {
    zfs = true;
  };
  boot.kernelParams = [ "nohibernate" ];

  ### ZFS requires a unique hostId (first 8 chars of machine-id from hardening.nix)
  networking.hostId = lib.mkDefault "b08dfa60";

  ### Use CachyOS-patched ZFS when CachyOS kernel is active
  boot.zfs = {
    package = lib.mkDefault config.boot.kernelPackages.zfs_cachyos;
    forceImportRoot = false;
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

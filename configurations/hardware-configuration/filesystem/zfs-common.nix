{ config, lib, pkgs, ... }:

{
  ### Enable ZFS support
  boot.supportedFilesystems = {
    zfs = true;
  };
  boot.kernelParams = [
    "nohibernate"
    "zfs.zfs_arc_max=4294967296"  ### 4 GiB max ARC
  ];

  ### ZFS requires a unique hostId (first 8 chars of machine-id from hardening.nix)
  networking.hostId = lib.mkDefault "b08dfa60";

  ### Use CachyOS-patched ZFS (available in cachyosKernels kernel packages)
  ### Falls back to upstream ZFS for non-CachyOS kernels
  boot.zfs = {
    package = lib.mkDefault (
      if builtins.hasAttr "zfs_cachyos" config.boot.kernelPackages
      then config.boot.kernelPackages.zfs_cachyos
      else pkgs.zfs
    );
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

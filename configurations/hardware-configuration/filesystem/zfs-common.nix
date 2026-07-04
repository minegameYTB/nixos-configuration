{ config, lib, pkgs, ... }:

{
  ### Enable ZFS support
  boot.supportedFilesystems = {
    zfs = true;
  };
  boot.kernelParams = [
    "nohibernate"
    ### 2 GiB max ARC (default, conservative for all RAM sizes)
    ### Calcul: 2 * 1024 * 1024 * 1024 = 2147483648
    "zfs.zfs_arc_max=2147483648"
    ### Explicit hostId for initrd (avoids hostId mismatch with pool label)
    "spl.spl_hostid=0xb08dfa60"
    ### Alternative for high-RAM machines (4 GiB):
    ### 4 * 1024 * 1024 * 1024 = 4294967296
    #"zfs.zfs_arc_max=4294967296"
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

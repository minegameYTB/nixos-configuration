{
  config,
  lib,
  pkgs,
  ...
}:

{
  ### ZFS support at boot level
  boot.supportedFilesystems = {
    zfs = true;
    btrfs = true;
    ext4 = true;
  };

  ### Kernel parameters tuning ZFS behaviour
  boot.kernelParams = [
    "nohibernate"

    ### 4 GiB max ARC (conservative for 16 GiB VMs)
    ### Calcul: 4 * 1024 * 1024 * 1024 = 4294967296
    #"zfs.zfs_arc_max=4294967296"

    ### Explicit hostId for initrd (avoids hostId mismatch with pool label)
    "spl.spl_hostid=0xb08dfa60"

    ### Reduce device timeout (VM firmware is slow)
    "systemd.device-timeout=30"

    ### Alternative for high-RAM machines (8 GiB):
    ### 8 * 1024 * 1024 * 1024 = 8589934592
    "zfs.zfs_arc_max=8589934592"
  ];

  ### Unique hostId required by ZFS
  ### (first 8 chars of machine-id from hardening.nix)
  networking.hostId = lib.mkDefault "b08dfa60";

  ### ZFS package: prefer CachyOS-patched version when available
  ### Falls back to upstream ZFS for non-CachyOS kernels
  boot.zfs = {
    package = lib.mkDefault (
      if builtins.hasAttr "zfs_cachyos" config.boot.kernelPackages then
        config.boot.kernelPackages.zfs_cachyos
      else
        pkgs.zfs
    );

    ### devNodes is set per-filesystem config (zfs vs btrfs)

    ### Do not force-import pools with -f
    forceImportRoot = false;
  };

  ### Monthly ZFS pool scrub
  services.zfs.autoScrub = {
    enable = true;
    interval = "monthly";
  };

  ### Monthly ZFS TRIM (SSD optimisation)
  services.zfs.trim = {
    enable = true;
    interval = "monthly";
  };

  ### Reset ZFS pool state after suspend/resume
  ### ZFS can leave the pool suspended when the underlying disk disappears
  ### during sleep (especially on VMs). This service clears error state
  ### and re-onlines devices after resume.
  systemd.services."zfs-resume" = {
    description = "Reset ZFS pool state after resume";
    after = [ "post-resume.target" ];
    wantedBy = [ "post-resume.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.zfs}/bin/zpool clear -f zroot 2>/dev/null || true
      ${pkgs.zfs}/bin/zpool online -e zroot 2>/dev/null || true
    '';
  };
}

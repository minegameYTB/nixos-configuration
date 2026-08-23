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

    ### Explicit hostId for initrd (avoids hostId mismatch with pool label)
    "spl.spl_hostid=0xb08dfa60"

    ### Reduce device timeout (VM firmware is slow)
    "systemd.device-timeout=30"

  ]
  ++ (
    if config.marker.hostProfile == "desktop" then
      [
        ### Alternative for high-RAM machines (8 GiB):
        ### 8 * 1024 * 1024 * 1024 = 8589934592
        "zfs.zfs_arc_min=1073741824" # 1G min
        "zfs.zfs_arc_max=6442450944" # 6G max
      ]
    else
      [
        ### 4 GiB max ARC (conservative for 16 GiB VMs)
        ### Calculation: 4 * 1024 * 1024 * 1024 = 4294967296
        "zfs.zfs_arc_min=536870912" # 512M min
        "zfs.zfs_arc_max=1073741824" # 1G max
      ]
  );

  ### Unique hostId required by ZFS
  ### (first 8 chars of machine-id from hardening.nix)
  networking.hostId = lib.mkDefault "b08dfa60";

  ### ZFS package: prefer CachyOS-patched version when available
  ### Falls back to upstream ZFS for non-CachyOS kernels.
  ### Must be the USERLAND package (zfs-user): it ships lib/udev
  ### (udev rules, vdev_id, zvol_id) required by the initrd.
  ### The kernel module package is picked up automatically via
  ### boot.zfs.modulePackage (selectModulePackage).
  ### NOTE: zfs_cachyos from the CachyOS flake is a combined
  ### kernel+userspace build, which is why it works as-is.
  boot.zfs = {
    package = lib.mkDefault (
      if builtins.hasAttr "zfs_cachyos" config.boot.kernelPackages then
        config.boot.kernelPackages.zfs_cachyos
      else
        pkgs.zfs
    );

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
      ${config.boot.zfs.package}/bin/zpool clear -f zroot 2>/dev/null || true
      ${config.boot.zfs.package}/bin/zpool online -e zroot 2>/dev/null || true
    '';
  };

  ### Ignore zfs pool in nautilus with udev
  services.udev.extraRules = ''
    # Hide ZFS member partitions
    ENV{ID_FS_TYPE}=="zfs_member", ENV{UDISKS_IGNORE}="1", ENV{UDISKS_PRESENTATION_HIDE}="1"
  '';

  ### For share* properties in zfs:
  ###   - sharenfs=<opts> → served by nfsd
  ###   - sharesmb=on     → dataset published as a samba usershare
  services.nfs.server.enable = true;

  services.samba = {
    enable = true;
    smbd.enable = true;
    openFirewall = true;

    ### Required for `zfs set sharesmb=on <dataset>`: `zfs share -a` publishes
    ### each dataset as a samba usershare via `net usershare add`, which needs
    ### /var/lib/samba/usershares (created here) and the [global] usershare
    ### settings injected by the module.
    ### Usage: zfs set sharesmb=on zroot/USERDATA/home
    ### Access requires a samba password: smbpasswd -a <user>
    usershares.enable = true;

    settings.global = {
      ### Datasets are owned by regular users but the usershare is created by
      ### root (zfs-share runs as root) — lift samba's ownership check,
      ### otherwise every ZFS share fails with NT_STATUS_ACCESS_DENIED.
      "usershare owner only" = false;

      ### Drop legacy SMB1 (security)
      "server min protocol" = "SMB2";
    };
  };

  ### Windows 10/11 discovery: NetBIOS browsing is dead there, wsdd answers
  ### WS-Discovery probes so ZFS/SMB shares show up in the "Network" view.
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  ### Fix boot ordering: upstream zfs-share.service orders after "smb.service"
  ### which does not exist on NixOS (unit is named samba-smbd.service), so
  ### `zfs share -a` could race against smbd startup and fail silently.
  systemd.services."zfs-share".after = [ "samba-smbd.service" ];
}

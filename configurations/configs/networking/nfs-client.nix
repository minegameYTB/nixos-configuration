{
  lib,
  config,
  pkgs,
  ...
}:

### NFS client — import this file to enable mounting remote NFS shares.
### Does NOT start an NFS server; only client utilities + rpcbind.
###
### Usage in a machine profile:
###   imports = [ ../configurations/configs/networking/nfs-client.nix ];
###
### Then define mounts via fileSystems, e.g.:
###   fileSystems."/mnt/nas" = {
###     device = "192.168.1.10:/volume";
###     fsType = "nfs";
###     options = [ "x-systemd.automount" "noauto" ];
###   };

{
  ### rpcbind is required for NFSv3 mount negotiation (portmapper).
  services.rpcbind.enable = true;

  ### nfs-utils provides mount.nfs, showmount, nfsstat, etc.
  environment.systemPackages = [ pkgs.nfs-utils ];

  ### NFSv4 idmapd — maps numeric UID/GID to names over NFSv4.
  ### Without this, NFSv4 mounts show "nobody" for file ownership.
  services.nfs.idmapd.settings = {
    General = {
      Verbosity = 3;
    };
    Mapping = {
      Method = "nsswitch";
    };
  };

  ### NFS client firewall: rpcbind (111), nfsd (2049),
  ### and lockd/mountd/statd (4000-4002, 20048) for NFSv3.
  networking.firewall = {
    allowedTCPPorts = [
      111
      2049
      4000
      4001
      4002
      20048
    ];
    allowedUDPPorts = [
      111
      2049
      4000
      4001
      4002
      20048
    ];
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nspawnctl;
  join = lib.concatStringsSep " ";
  esc = lib.escapeShellArg;
in

{
  ### Options mirroring nspawnctl's runtime constants. They are written into
  ### /etc/nspawnctl.conf (declarative); editing that file by hand only works
  ### on standalone (non-NixOS) installs, where the script's own defaults
  ### apply otherwise.
  options.nspawnctl = {
    enable = lib.mkEnableOption "nspawnctl machine manager (systemd-nspawn on ZFS)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.pkgsConfig.nspawnctl;
      description = "nspawnctl package to install.";
    };

    machinesDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/machines";
      description = "Mount point of machine datasets (MACHINES_DIR).";
    };

    datasetRoot = lib.mkOption {
      type = lib.types.str;
      default = "zroot/MACHINE";
      description = "ZFS dataset root holding one dataset per machine (DATASET_ROOT).";
    };

    bridge = lib.mkOption {
      type = lib.types.str;
      default = "systemd-nspawn";
      description = "Bridge receiving container veth pairs (BRIDGE).";
    };

    defaultQuota = lib.mkOption {
      type = lib.types.str;
      default = "10G";
      description = "Default dataset refquota for new machines (DEFAULT_QUOTA).";
    };

    defaultCompression = lib.mkOption {
      type = lib.types.str;
      default = "zstd-3";
      description = "Default ZFS compression for new machine datasets (DEFAULT_COMPRESSION).";
    };

    debootstrapMirror = lib.mkOption {
      type = lib.types.str;
      default = "http://deb.debian.org/debian";
      description = "Debian mirror used by 'new --debootstrap' (DEBOOTSTRAP_MIRROR).";
    };

    lxRepos = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "TritonDataCenter/lx-images"
        "omniosorg/lx-images"
      ];
      description = "GitHub repositories scanned by the smartos source (LX_REPOS).";
    };

    lxcStreams = lib.mkOption {
      type = lib.types.str;
      default = "https://images.linuxcontainers.org/streams/v1/images.json";
      description = "linuxcontainers.org streams metadata URL (LXC_STREAMS).";
    };

    ubuntuCloud = lib.mkOption {
      type = lib.types.str;
      default = "https://cloud-images.ubuntu.com";
      description = "Ubuntu cloud image mirror root (UBUNTU_CLOUD).";
    };

    extraSources = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Manual image sources as "name=template" URL templates ({os}, {version}).
        Written to NSPAWNCTL_EXTRA_SOURCES in /etc/nspawnctl.conf, e.g.
        "mirror=https://mirror.example.com/images/{os}-{version}.tar.xz".
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    ### systemd-nspawn (machinectl, nspawn)
    boot.enableContainers = true;

    ### Container management wrapper: sudo nspawnctl new/net/remove <machine>
    environment.systemPackages = [ cfg.package ];

    ### Declarative runtime config consumed by nspawnctl (see options above)
    environment.etc."nspawnctl.conf".text = ''
      MACHINES_DIR=${esc cfg.machinesDir}
      DATASET_ROOT=${esc cfg.datasetRoot}
      BRIDGE=${esc cfg.bridge}
      DEFAULT_QUOTA=${esc cfg.defaultQuota}
      DEFAULT_COMPRESSION=${esc cfg.defaultCompression}
      DEBOOTSTRAP_MIRROR=${esc cfg.debootstrapMirror}
      LX_REPOS=${esc (join cfg.lxRepos)}
      LXC_STREAMS=${esc cfg.lxcStreams}
      UBUNTU_CLOUD=${esc cfg.ubuntuCloud}
      NSPAWNCTL_EXTRA_SOURCES=(${join (map esc cfg.extraSources)})
    '';

    ### machined launches containers with `-U --settings=override`, which ignores
    ### privileged [Exec] settings (Capability=) from .nspawn files. Under -U
    ### (user namespaces) the bounding set is fixed before entering the
    ### namespace, so even --capability= cannot raise CAP_NET_RAW afterwards —
    ### the DHCP client silently never starts. Run without -U and pass
    ### --capability=CAP_NET_RAW on the command line instead.
    systemd.services."systemd-nspawn@" = {
      serviceConfig.ExecStart = [
        ""
        "${pkgs.systemd}/bin/systemd-nspawn --quiet --keep-unit --boot --link-journal=try-guest --network-veth --settings=override --capability=CAP_NET_RAW --machine=%i"
      ];
    };
  };
}

{
  device ? throw "Set this to your disk device, e.g. /dev/sda",
  size ? throw "Set size for partition e.g. 100G or 100%, GPT only accept fixe value or 100% for the disk size",
  ...
}:

{
  disko.devices = {
    disk = {
      main = {
        inherit device;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ### ESP partition
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
                extraArgs = [
                  "-n"
                  "EFI"
                ];
              };
            };

            ### ZFS partition
            zroot = {
              inherit size;
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };

    ### ZFS pool
    zpool = {
      zroot = {
        type = "zpool";
        mode = "";
        rootFsOptions = {
          mountpoint = "none";
          acltype = "posixacl";
        };
        datasets = {
          ### System datasets
          "ROOT" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "128K";
            };
          };
          "ROOT/nixos" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "128K";
              refquota = "3G";
            };
          };

          ### Home dataset
          "home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {
              mountpoint = "legacy";
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "128K";
              refquota = "50G";
            };
          };

          ### Nix dataset
          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "128K";
            };
          };

          ### Nix var dataset (build artefacts, DB — refquota protects store)
          "nix/var" = {
            type = "zfs_fs";
            mountpoint = "/nix/var";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "128K";
              refquota = "30G";
            };
          };
          "nix/var/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix/var/nix";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "16K";
            };
          };
          "nix/var/nix/db" = {
            type = "zfs_fs";
            mountpoint = "/nix/var/nix/db";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "16K";
            };
          };

          ### Var datasets — each FHS directory under /var gets its own dataset
          ### (inspired by FreeBSD's default ZFS layout)
          "var" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "1M";
            };
          };
          "var/db" = {
            type = "zfs_fs";
            mountpoint = "/var/db";
            options = {
              mountpoint = "legacy";
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "64K";
            };
          };
          "var/lib" = {
            type = "zfs_fs";
            mountpoint = "/var/lib";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "128K";
            };
          };
          "var/lib/libvirt" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/libvirt";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "16K";
            };
          };
          "var/lib/libvirt/images" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/libvirt/images";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "64K";
            };
          };
          "var/log" = {
            type = "zfs_fs";
            mountpoint = "/var/log";
            options = {
              mountpoint = "legacy";
              refquota = "2G";
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "16K";
            };
          };
          "var/cache" = {
            type = "zfs_fs";
            mountpoint = "/var/cache";
            options = {
              mountpoint = "legacy";
              refquota = "5G";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              sync = "disabled";
              recordsize = "128K";
            };
          };
          "var/spool" = {
            type = "zfs_fs";
            mountpoint = "/var/spool";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "64K";
            };
          };
          "var/tmp" = {
            type = "zfs_fs";
            mountpoint = "/var/tmp";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              refquota = "30G";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "64K";
              setuid = "off";
              exec = "off";
            };
          };

          ### Reserved space
          "reserved" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              refreservation = "10G";
            };
          };
        };
      };
    };
  };
}

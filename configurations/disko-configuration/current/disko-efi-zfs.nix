{
  device ? throw "Set this to your disk device, e.g. /dev/sda",
  size ? throw "Set size for partition e.g. 100G or 100%, GPT only accept fixed value or 100% for the disk size",
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
              size = "1024M";
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

          ### User data container (isolated from OS rollbacks)
          "USERDATA" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "128K";
              primarycache = "metadata";
              devices = "off";
            };
          };
          "USERDATA/root" = {
            type = "zfs_fs";
            mountpoint = "/root";
            options = {
              mountpoint = "legacy";
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              refquota = "5G";
            };
          };
          "USERDATA/home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {
              mountpoint = "legacy";
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              refquota = "100G";
              setuid = "off";
            };
          };

          ### "Export" container dataset (temporary datasets, mixed content:
          ### keep neutral 128K default, tune recordsize per child at creation)
          "EXPORT" = {
            type = "zfs_fs";
            # Herited option for this container
            options = {
              mountpoint = "none";
              compression = "zstd-6";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              setuid = "off";
              exec = "off";
              devices = "off";
            };
          };

          ### Nix dataset
          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "legacy";
              compression = "zstd-3";
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
              refquota = "10G";
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
              recordsize = "64K";
              refquota = "60G";
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
              refquota = "3G";
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
              recordsize = "128K";
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
              refquota = "10G";
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
              compression = "off";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "64K";
              primarycache = "metadata";
            };
          };
          "var/lib/AccountsService" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/AccountsService";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "16K";
              devices = "off";
              exec = "off";
              setuid = "off";
              refquota = "60M";
            };
          };
          "var/lib/NetworkManager" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/NetworkManager";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "16K";
              devices = "off";
              exec = "off";
              setuid = "off";
              refquota = "60M";
            };
          };
          "var/lib/docker" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/docker";
            options = {
              mountpoint = "legacy";
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "64K";
              refquota = "30G";
            };
          };
          "var/lib/flatpak" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/flatpak";
            options = {
              mountpoint = "legacy";
              compression = "zstd-6";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "64K";
              refquota = "15G";
            };
          };
          "var/lib/fwupd" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/fwupd";
            options = {
              mountpoint = "legacy";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "16K";
              devices = "off";
              exec = "off";
              setuid = "off";
              refquota = "2G";
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
              setuid = "off";
              devices = "off";
              exec = "off";
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
              devices = "off";
              exec = "off";
            };
          };

          ### Machine container datasets (systemd-nspawn /var/lib/machines)
          "MACHINE" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              compression = "lz4";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "128K";
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

          ### ZVol container datasets
          "zvol" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              compression = "lz4";
              primarycache = "metadata";
            };
          };
          "zvol/disk" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              compression = "lz4";
            };
          };
          "zvol/vm" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              volmode = "dev";
              compression = "lz4";
            };
          };
        };
      };
    };
  };
}

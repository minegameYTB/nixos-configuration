{
  device ? throw "Set this to your disk device, e.g. /dev/sda",
  size ? throw "Set size for partition e.g. 100G or 100%, GPT only accept fixed value or 100% for the disk size",
  keyFile ? throw "Set path to the raw partition holding the ZFS encryption key, e.g. /dev/disk/by-id/mmc-APPSD_0x00000354-part1 or /dev/sdb1",
  ...
}:

let
  inherit keyFile;

  encryptedOpts = {
    encryption = "aes-256-gcm";
    keyformat = "raw";
    keylocation = "file:///tmp/zfs-key";
  };
in

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
          ### --- Encrypted datasets ---

          ### Root dataset (encrypted, parent of ROOT/nixos)
          "ROOT" = {
            type = "zfs_fs";
            options = encryptedOpts // {
              mountpoint = "none";
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "1M";
            };
            postCreateHook = ''
              zfs set keylocation="file://${keyFile}" "zroot/ROOT"
            '';
          };
          "ROOT/nixos" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              mountpoint = "legacy";
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "1M";
              quota = "3G";
            };
          };

          ### Home dataset (encrypted)
          "home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = encryptedOpts // {
              mountpoint = "legacy";
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "1M";
            };
            postCreateHook = ''
              zfs set keylocation="file://${keyFile}" "zroot/home"
            '';
          };

          ### --- Unencrypted datasets ---

          ### Nix dataset (unencrypted for performance)
          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "legacy";
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "1M";
              primarycache = "metadata";
            };
          };

          ### Nix var dataset (build artefacts, DB — refquota protects store)
          "nix/var" = {
            type = "zfs_fs";
            mountpoint = "/nix/var";
            options = {
              mountpoint = "legacy";
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "128K";
              refquota = "30G";
            };
          };

          ### Var datasets — each FHS directory under /var gets its own dataset
          ### (inspired by FreeBSD's default ZFS layout)
          ### var parent is encrypted; children inherit encryption automatically.
          "var" = {
            type = "zfs_fs";
            options = encryptedOpts // {
              mountpoint = "none";
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "1M";
            };
            postCreateHook = ''
              zfs set keylocation="file://${keyFile}" "zroot/var"
            '';
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
              compression = "zstd-3";
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
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "1M";
            };
          };
          "var/log" = {
            type = "zfs_fs";
            mountpoint = "/var/log";
            options = {
              mountpoint = "legacy";
              quota = "2G";
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
              quota = "5G";
              compression = "zstd-3";
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
              compression = "zstd-3";
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
              compression = "zstd-3";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "64K";
              setuid = "off";
              exec = "off";
            };
          };
          ### Swap volume (unencrypted)
          "swap" = {
            type = "zfs_volume";
            size = "8G";
            options = {
              volblocksize = "16384";
            };
            content = {
              type = "swap";
            };
          };

          ### Reserved space (unencrypted)
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

{
  device ? throw "Set this to your disk device, e.g. /dev/sda",
  size ? throw "Set size for the partition e.g. 100% or 500G, GPT only accept fixe value or 100% for the disk size",
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
            ESP = {
              size = "512M";
              type = "EF00";
              priority = 1;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            zfs = {
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

    zpool = {
      zroot = {
        type = "zpool";
        options = {
          #ashift = "12";
          autotrim = "on";
          cachefile = "none";
        };
        rootFsOptions = {
          acltype = "posixacl";
          xattr = "sa";
          compression = "zstd";
          #normalization = "formD";
          atime = "off";
          "com.sun:auto-snapshot" = "false";
        };
        mountpoint = "/";

        datasets = {
          nix = {
            type = "zfs_fs";
            options = {
              compression = "zstd-5";
              atime = "off";
              "com.sun:auto-snapshot" = "false";
            };
            mountpoint = "/nix";
          };

          "nix/var" = {
            type = "zfs_fs";
            options = {
              compression = "zstd-5";
              atime = "off";
              #recordsize = "1M";
              "com.sun:auto-snapshot" = "false";
            };
            mountpoint = "/nix/var";
          };

          var = {
            type = "zfs_fs";
            options = {
              compression = "zstd-5";
              atime = "off";
              "com.sun:auto-snapshot" = "false";
            };
            mountpoint = "/var";
          };

          "var/log" = {
            type = "zfs_fs";
            options = {
              compression = "zstd-5";
              "com.sun:auto-snapshot" = "true";
            };
            mountpoint = "/var/log";
          };

          "var/cache" = {
            type = "zfs_fs";
            options = {
              compression = "zstd-5";
              "com.sun:auto-snapshot" = "false";
            };
            mountpoint = "/var/cache";
          };

          "var/tmp" = {
            type = "zfs_fs";
            options = {
              compression = "zstd-5";
              "com.sun:auto-snapshot" = "false";
            };
            mountpoint = "/var/tmp";
          };

          home = {
            type = "zfs_fs";
            options = {
              compression = "zstd-5";
              atime = "off";
              "com.sun:auto-snapshot" = "true";
            };
            mountpoint = "/home";
          };

          ### See https://wiki.nixos.org/wiki/ZFS#Reservations
          reserved = {
            type = "zfs_fs";
            options = {
              refreservation = "10G";
              mountpoint = "none";
              canmount = "off";
              "com.sun:auto-snapshot" = "false";
            };
          };

        };
      };
    };
  };
}

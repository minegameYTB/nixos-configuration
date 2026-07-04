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
    zpool = {
      zroot = {
        type = "zpool";
        mode = "";
        datasets = {
          "ROOT" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              compression = "zstd";
            };
          };
          "ROOT/nixos" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              mountpoint = "legacy";
              compression = "zstd";
            };
          };
          "home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {
              mountpoint = "legacy";
              compression = "zstd";
            };
          };
          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "legacy";
              compression = "zstd";
            };
          };
          "var" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              compression = "zstd";
            };
          };
          "var/log" = {
            type = "zfs_fs";
            mountpoint = "/var/log";
            options = {
              mountpoint = "legacy";
              compression = "zstd";
            };
          };
          "var/cache" = {
            type = "zfs_fs";
            mountpoint = "/var/cache";
            options = {
              mountpoint = "legacy";
              compression = "zstd";
            };
          };
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

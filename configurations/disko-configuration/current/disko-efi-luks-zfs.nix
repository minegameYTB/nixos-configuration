{
  device ? throw "Set this for your disk device, e.g. /dev/sda",
  size ? throw "Set size for partition e.g; 100G or 100%, GPT only accept fixed value or 100% for disk size",
  keyFile ? throw "Set path of secret keyfile e.g. /run/media/$USER/usbVolume or /dev/mmcblk0 for raw device who host key in raw partition",
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

            ### LUKS encrypted partition
            luks = {
              inherit size;
              content = {
                type = "luks";
                name = "luks-encrypted";
                settings = {
                  allowDiscards = true;
                  keyFileSize = 4096;
                  inherit keyFile;
                  additionalKeyFiles = [ "/tmp/additionalSecret.key" ];
                };
                content = {
                  type = "zfs";
                  pool = "zroot";
                };
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
        };
        datasets = {
          ### System datasets
          "ROOT" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              compression = "zstd";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "1M";
            };
          };
          "ROOT/nixos" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              mountpoint = "legacy";
              compression = "zstd";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "1M";
            };
          };

          ### Home dataset
          "home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = {
              mountpoint = "legacy";
              compression = "zstd";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "1M";
            };
          };

          ### Nix dataset (primarycache=metadata for /nix)
          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              mountpoint = "legacy";
              compression = "zstd";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              primarycache = "metadata";
            };
          };

          ### Var datasets
          "var" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              compression = "zstd";
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
              compression = "zstd";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "1M";
            };
          };
          "var/cache" = {
            type = "zfs_fs";
            mountpoint = "/var/cache";
            options = {
              mountpoint = "legacy";
              compression = "zstd";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "1M";
            };
          };

          ### Swap volume
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

          ### Reserved space
          "reserved" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              refreservation = "10G";
              atime = "off";
              xattr = "sa";
              dnodesize = "auto";
              recordsize = "1M";
            };
          };
        };
      };
    };
  };
}

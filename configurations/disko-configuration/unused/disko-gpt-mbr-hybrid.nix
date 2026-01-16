{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/vda";
        #device = "/dev/disk/by-id/ata-Samsung_SSD_850_EVO_250GB_S21PNXAGB12345";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
            };
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/efi";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [
                  "-L"
                  "nixos-root"
                ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd:5"
                      "noatime"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}

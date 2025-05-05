{
  disko.devices = {
    disk = {
      main = {
        ### use temporary loop0 for test
        device = "/dev/loop0"
        #device = "/dev/disk/by-id/ata-CT500BX500SSD1_2349E88829C8";
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
                extraArgs = [ "-n" "EFI" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "btrfs";
                extraArgs = [ "-L" "nixos-root" ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [ 
                      "compress=zstd:10"
                      "noatime" 
                    ];
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd:10"
                      "noatime"
                    ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd:10" 
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


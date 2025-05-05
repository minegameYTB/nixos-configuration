{
  disko.devices = {
    disk = {
      main = {
        ### Main disk of hp-probook (change this bfor installing on another computer)
        ### (uncomment to use another disk device)
        device = "/dev/disk/by-id/ata-CT500BX500SSD1_2349E88829C8";
        ### For sda for example
        #device = "/dev/sda";
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
                type = "btrfs";
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


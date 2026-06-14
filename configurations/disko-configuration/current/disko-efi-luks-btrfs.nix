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
            luks = {
              inherit size;
              content = {
                type = "luks";
                name = "luks-encrypted";
                settings = {
                  allowDiscards = true;
                  keyFileSize = 4096;
                  inherit keyFile;
                  additionalKeyFiles = [ "/tmp/additionalSecret.key" ]; # For recovery
                };
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
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = [
                        "compress=zstd:5"
                        "noatime"
                      ];
                    };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [
                        "compress=zstd:5"
                        "noatime"
                      ];
                    };
                    "@log" = {
                      mountpoint = "/var/log";
                      mountOptions = [
                        "compress=zstd:5"
                        "noatime"
                      ];
                    };
                    "@cache" = {
                      mountpoint = "/var/cache";
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
  };
}

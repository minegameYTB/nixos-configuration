{
  device ? throw "Set this to your disk device, e.g. /dev/sda",
  size ? throw "Set size for partition e.g. 100G or 100%, GPT only accept fixe value or 100% for the disk size",
  keyFile ? throw "Set path of secret keyfile e.g. /run/media/$USER/usbVolume",
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
                  # Run nix run nixpkgs#openssl -- rand -out /tmp/secret.key 512 before initialize disk with this expression (via install script, and add warning for key conservation)
                  keyFileSize = 512;
                  inherit keyFile;
                };
                #additionalKeyFiles = [ "/tmp/additionalSecret.key" ]; # Other key (for recovery)
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

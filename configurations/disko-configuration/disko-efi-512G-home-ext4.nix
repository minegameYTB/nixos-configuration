{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/disk/by-id/ata-CT500BX500SSD1_2349E88829C8";
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
                ### Add label
                extraArgs = [
                  "-n"
                  "EFI"
                ];
              };
            };
            root = {
              size = "220G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                extraArgs = [
                  "-L"
                  "nixos-root"
                ];
              };
            };
            home = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/home";
                extraArgs = [
                  "-L"
                  "nixos-home"
                ];
              };
            };
          };
        };
      };
    };
  };
}

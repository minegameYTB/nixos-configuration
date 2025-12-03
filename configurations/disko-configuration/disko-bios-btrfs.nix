{
  disko.devices = {
    disk = {
      sda = {
        device = "/dev/vda";
        type = "disk";
        content = {
          type = "table";
          format = "msdos";
          partitions = [
            {
              name = "root";
              part-type = "primary";
              start = "1M";
              end = "100%";
              bootable = true;
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
            }
          ];
        };
      };
    };
  };
}

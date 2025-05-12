{
  disko.devices = {
    disk = {
      main = {
        ### point to /dev/vda or /dev/sda
        device = "/dev/disk/by-diskseq/1";
        type = "disk";
        content = {
          type = "mbr";
          partitions = {
            boot = {
              size = "512M";
              type = "primary";
              bootable = true;
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/boot";
                extraArgs = [ "-L" "boot" ];
              };
            };
            root = {
              size = "100%";
              type = "primary";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                extraArgs = [ "-L" "nixos-root" ];
              };
            };
          };
        };
      };
    };
  };
}

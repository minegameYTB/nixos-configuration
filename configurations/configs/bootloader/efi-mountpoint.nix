{ config, ... }:

{
  ### Use efi partitionment
  fileSystems."/boot" = {
    device = "/dev/disk/by-fs/vfat/label/EFI";
    fsType = "vfat";
    options = [
      "noexec"
      "nodev"
      "nosuid"
      "noatime"
      "fmask=0077"
      "dmask=0077"
    ];
  };
}

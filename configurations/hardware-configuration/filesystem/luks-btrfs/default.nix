{
  lib,
  config,
  ...
}:

{
  ### Import common btrfs config
  imports = [ ../btrfs-common.nix ];

  ### Luks specific settings
  boot.initrd.kernelModules = [
    ### For luks keyFile support
    "mmc_block"
  ];

  # Settings for luks
  boot.initrd.luks.devices."luks-encrypted" = {
    device = "/dev/disk/by-fs/crypto_LUKS/partlabel/disk-main-luks";

    # For keyFile, make sure to change this path (and user used) in case of a fork and using luks encryption
    keyFile = lib.mkDefault "/dev/disk/by-id/mmc-APPSD_0x00000354-part1";
    keyFileSize = 4096;
    keyFileTimeout = 5;
  };

  ### Mountpoint
  fileSystems."/" = {
    device = "/dev/mapper/luks-encrypted";
    fsType = "btrfs";
    options = [
      "subvol=@"
      "compress=zstd:5"
      "noatime"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/mapper/luks-encrypted";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd:5"
      "noatime"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/mapper/luks-encrypted";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress=zstd:5"
      "noatime"
    ];
  };
  fileSystems."/var/log" = {
    device = "/dev/mapper/luks-encrypted";
    fsType = "btrfs";
    options = [
      "subvol=@log"
      "compress=zstd:5"
      "noatime"
    ];
  };
  fileSystems."/var/cache" = {
    device = "/dev/mapper/luks-encrypted";
    fsType = "btrfs";
    options = [
      "subvol=@cache"
      "compress=zstd:5"
      "noatime"
    ];
  };

  fileSystems."/var/lib/libvirt" = lib.mkIf config.virtualisation.libvirtd.enable {
    device = "/dev/mapper/luks-encrypted";
    fsType = "btrfs";
    options = [
      "subvol=@libvirt"
      "compress=zstd:5"
      "noatime"
    ];
  };
}

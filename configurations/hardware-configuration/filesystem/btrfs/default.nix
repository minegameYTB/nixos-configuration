{
  config,
  lib,
  pkgs,
  ...
}:

{
  ### Import common btrfs config
  imports = [ ../btrfs-common.nix ];

  ### Mount Point
  fileSystems."/" = {
    #device = "/dev/disk/by-label/nixos-root";
    label = "nixos-root";
    fsType = "btrfs";
    options = [
      "subvol=@"
      "compress=zstd:5"
      "noatime"
    ];
  };

  fileSystems."/home" = {
    label = "nixos-root";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd:5"
      "noatime"
    ];
  };

  fileSystems."/nix" = {
    label = "nixos-root";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress=zstd:5"
      "noatime"
    ];
  };
  fileSystems."/var/log" = {
    label = "nixos-root";
    fsType = "btrfs";
    options = [
      "subvol=@log"
      "compress=zstd:5"
      "noatime"
    ];
  };
  fileSystems."/var/cache" = {
    label = "nixos-root";
    fsType = "btrfs";
    options = [
      "subvol=@cache"
      "compress=zstd:5"
      "noatime"
    ];
  };

  fileSystems."/var/lib/libvirt" = lib.mkIf config.virtualisation.libvirtd.enable {
    label = "nixos-root";
    fsType = "btrfs";
    options = [
      "subvol=@libvirt"
      "compress=zstd:5"
      "noatime"
    ];
  };
}

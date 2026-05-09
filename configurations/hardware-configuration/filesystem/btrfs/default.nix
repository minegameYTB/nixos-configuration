{
  config,
  lib,
  pkgs,
  ...
}:

{
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

  ### Btrfs scrub maintenance
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
    interval = "monthly";
  };

  boot.supportedFilesystems = {
    btrfs = true;
    ext4 = true;
  };
}

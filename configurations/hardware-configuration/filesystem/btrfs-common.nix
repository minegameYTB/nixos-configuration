{ config, ... }:

{
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

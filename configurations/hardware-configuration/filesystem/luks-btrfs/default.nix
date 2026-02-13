{ config, pkgs, ... }:

{
  ### Import btrfs filesystem (luksFS is used as a container with btrfs inside)
  imports = [ ../btrfs ];

  ### Luks specific settings
  # Set mountpoint for keyFile device

  # Settings for luks
  boot.initrd.luks.devices."luks-encrypted" = {
    device = "/dev/";

    # For keyFile, make sure to change this path (and user used) in case of a fork and using luks encryption
    keyFile = "/run/media/${config.users.users.minegame.name}/keys/secret.key";
  };
}

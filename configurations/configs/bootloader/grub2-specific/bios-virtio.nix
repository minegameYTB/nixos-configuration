{ config, ... }:

{
  ### Import grub2 settings expression
  imports = [ ../grub2.nix ];

  ### Specific settings for grub2 bios mode (virtio)
  boot.loader.grub.device = "/dev/vda";
}

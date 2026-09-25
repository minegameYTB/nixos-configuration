{ config, pkgs, ... }:

{
  ### Import efi mountpoint expression
  imports = [
    ./common.nix
    ./efi-mountpoint.nix
  ];

  ### Systemd-boot
  boot.loader = {
    systemd-boot = {
      enable = true;
    };
    ### Enable EFI editable variable
    efi.canTouchEfiVariables = true;
  };
}

{ config, pkgs, ... }:

{
  ### Import efi mountpoint expression
  imports = [ ./efi-mountpoint.nix ];

  ### Systemd-boot
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 25;
    };
    ### Enable EFI editable variable
    efi.canTouchEfiVariables = true;
  };
}

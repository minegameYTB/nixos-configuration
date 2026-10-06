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
      ### Automatic Boot Assessment: new entries boot with a counter,
      ### blessed once boot-complete.target is reached; a counter at zero
      ### is skipped for the previous generation (no UKI/Secure Boot needed).
      bootCounting = {
        enable = true;
        tries = 3;
      };
    };
    ### Enable EFI editable variable
    efi.canTouchEfiVariables = true;
  };
}

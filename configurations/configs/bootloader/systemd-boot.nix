{ config, pkgs, ... }:

{
  ### Import efi mountpoint expression
  imports = [ ./efi-mountpoint.nix ];

  ### Systemd-boot
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;

      ### Enable Memtest86+ entry for all systemd-boot based configuration
      # Add entry
      extraEntries."memtest86plus.conf" = ''
        title Memtest86+
        efi /efi/memtest86plus/memtest.efi
        sort-key z_memtest
      '';

      # Export memtest86plus to $BOOT directory
      extraFiles = {
        "efi/memtest86plus/memtest.efi" = "${pkgs.memtest86plus}/memtest.efi";
      };
    };
    ### Enable EFI editable variable
    efi.canTouchEfiVariables = true;
  };
}

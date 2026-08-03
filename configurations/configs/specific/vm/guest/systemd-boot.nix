{ config, lib, ... }:

{
  ### Make the systemd-boot menu fully visible on small VM screens
  ### "max" switches the EFI console/GOP to the highest resolution
  ### available on the virtual display, so the whole menu fits.
  ### Only applies to EFI VMs (GRUB/BIOS VMs are unaffected).
  boot.loader.systemd-boot.consoleMode = lib.mkIf config.boot.loader.systemd-boot.enable "max";
}

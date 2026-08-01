{ config, pkgs, ... }:

{
  powerManagement.enable = true;
  powerManagement.powertop.enable = true;

  ### Fix mouse disconnecting on this laptop
  ### The 2.4G mouse sits behind a USB hub (214b:7250) that gets suspended by
  ### USB autosuspend (default 2s idle) — the cheap dongle never wakes up and
  ### the whole hub is lost ("USB disconnect"), forcing a replug.
  ### Disabling autosuspend globally is powertop-proof: powertop --auto-tune
  ### sets power/control=auto, but with a negative delay no device suspends.
  boot.kernelParams = [ "usbcore.autosuspend=-1" ];
}

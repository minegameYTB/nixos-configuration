{ ... }:

let
  configurationLimit = 30;
in
{
  boot.loader = {
    grub.configurationLimit = configurationLimit;
    systemd-boot.configurationLimit = configurationLimit;
  };
}

{ config, pkgs, ... }:

{
  ### Enable vmware workstation
  virtualisation.vmware.host = {
    enable = true;
    package = pkgs.vmware-workstation.override {
      enableInstaller = true;
    };
  };
}

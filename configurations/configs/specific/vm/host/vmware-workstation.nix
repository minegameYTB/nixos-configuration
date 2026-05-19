{ config, pkgs, ... }:

{
  ### Enable vmware workstation
  virtualisation.vmware.host = {
    enable = true;
    exposeWindowsVMwareToolIso.enable = true; # Custom module (see "/configurations/modules/virtualisation/vmware-ws-iso.nix" for more info for is implementation)
    package = pkgs.vmware-workstation.overrideAttrs (oldAttrs: {
      installPhase = (oldAttrs.installPhase or "") + ''
        ### Install vmware tools for windows (with .bundle file)
        echo "Installing VMware Tools"
        unpacked="unpacked/vmware-tools-windows"
        cp -r $unpacked/* $out/lib/vmware/isoimages/
      '';
    });
  };

}

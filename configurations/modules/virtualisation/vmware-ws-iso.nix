{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.virtualisation.vmware.host;
  cfgPkg = cfg.package;
in
{
  options.virtualisation.vmware.host.exposeWindowsVMwareToolIso = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose (via /etc/vmware/isoimages) the windows vmware tools iso";
    };
  };

  ### -- Implementation --
  config = lib.mkIf cfg.enable {
    environment.etc."vmware/isoimages" = {
      source = "${cfgPkg}/lib/vmware/isoimages";
    };
  };
}

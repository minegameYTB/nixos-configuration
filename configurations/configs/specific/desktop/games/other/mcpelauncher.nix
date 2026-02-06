{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs.pkgsUnstable; [
    mcpelauncher-ui-qt
  ];
}

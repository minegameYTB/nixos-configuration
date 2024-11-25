{ config, pkgs, ... }:

{
 powerManagement.enable = true;
 powerManagement.powertop.enable = true;
}

{ config, pkgs, ... }:

{
 ### Waydroid
 virtualisation.waydroid = {
   enable = true;
 };

 ### Add pyclip
 environment.systemPackages = with pkgs; [
   python313Packages.pyclip
 ];
}

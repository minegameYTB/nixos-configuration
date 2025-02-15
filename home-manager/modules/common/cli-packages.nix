{ config, pkgs, ... }:


 let
   ### Add external packages
   sshrm = pkgs.callPackage ../../../pkgs/sshrm {};
 in
{
 # Home Manager needs a bit of information about you and the paths it should
 # manage.
 home = {
   username = "minegame";
   homeDirectory = "/home/minegame";
 };

 home.packages = with pkgs; [
        
   ### Utilities
   jq
   fx
   screen
   gh
    
   ### External packages
   sshrm
 ];

}

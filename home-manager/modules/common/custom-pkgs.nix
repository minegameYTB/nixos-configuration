{ config, pkgs, ... }:

 let
   ### Add external packages
   sshrm = pkgs.callPackage ../../../pkgs/sshrm {};
   fhsEnv-shell = pkgs.callPackage ../../../pkgs/fhsEnv-dev {};
 in
{
 # Home Manager needs a bit of information about you and the paths it should
 # manage.
 home = {
   username = "minegame";
   homeDirectory = "/home/minegame";
 };

 home.packages = with pkgs; [
   ### Custom packages
   sshrm
   fhsEnv-shell
 ];

}

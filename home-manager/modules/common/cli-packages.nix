{ config, pkgs, ... }:

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
   ### Add sshrm as a package from my repo (nurpkgs-repo) through NUR
   nur.repos.minegameYTB.sshrm
   nur.repos.minegameYTB.fhsEnv-dev
 ];

}

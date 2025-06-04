### Provide pkgsExtra (define in flake (in specialArgs)) attribute to use pkgs-unstable for lutris
{ config, pkgsExtra, ... }:

{
 ### Add lutris (define override to add wineStaging in the environment of lutris)
 environment.systemPackages = with pkgsExtra.pkgs-unstable; [
   (lutris.override {
     extraPackages = [ wineWowPackages.staging ];
   });
 ]
}

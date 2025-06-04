### Call pkgsExtra to use latest lutris and wineStaging
{ config, pkgsExtra, ... }:

{
 ### Add lutris (define override to add wineStaging in the environment of lutris)
 environment.systemPackages = with pkgsExtra.pkgs-unstable; [
   (lutris.override {
     extraPkgs = pkgs: [ wineWowPackages.base ];
   })
 ];
}

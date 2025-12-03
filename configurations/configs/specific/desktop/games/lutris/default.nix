### Call pkgsExtra to use latest lutris and wineStaging
{ config, pkgs, ... }:

{
  ### Add lutris (define override to add wineStaging in the environment of lutris)
  environment.systemPackages = with pkgs; [
    (lutris.override {
      extraPkgs = pkgs: [ wineWowPackages.staging ];
      extraLibraries = pkgs: [
        libadwaita
        gtk4
      ];
    })
  ];
}

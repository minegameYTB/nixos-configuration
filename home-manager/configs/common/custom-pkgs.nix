{ config, pkgs, nurpkgs-repo-minegameYTB, ... }:

 let
   ### Add external packages
  #sshrm = pkgs.callPackage ../../../pkgs/sshrm {};
  #fhsEnv-shell = pkgs.callPackage ../../../pkgs/fhsEnv-dev {};
 in
{
 home.packages = 
   (with nurpkgs-repo-minegameYTB.legacyPackages.${pkgs.stdenvNoCC.hostPlatform.system}; [
     ### Custom packages
     ### Add custom-pkgs from my repo (nurpkgs-repo)
     sshrm
     editor.msedit-rs
   ])
   ++
   (with pkgs; [
     ### With nur namespace
     #nur.repos.minegameYTB.sshrm
 ]);
}

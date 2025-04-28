{ config, pkgs, ... }:

 let
   ### Add external packages
  #sshrm = pkgs.callPackage ../../../pkgs/sshrm {};
  #fhsEnv-shell = pkgs.callPackage ../../../pkgs/fhsEnv-dev {};
 in
{
 home.packages = with pkgs; [
    ### Custom packages
    ### Add custom-pkgs from my repo (nurpkgs-repo) through NUR
    nur.repos.minegameYTB.sshrm
  ];
}

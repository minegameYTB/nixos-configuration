{ config, pkgs, ... }:

let
  ### Add external packages
 #sshrm = pkgs.callPackage ../pkgs/sshrm {};
in
{
 
 imports = [
   ./configs/common/cli-packages.nix
   ../home-manager/configs/common/custom-pkgs.nix
   ./configs/common/config.nix
 ];

 home.stateVersion = "24.05"; # Please read the comment before changing.
}

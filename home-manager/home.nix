{ config, pkgs, ... }:

let
  ### Add external packages
 #sshrm = pkgs.callPackage ../pkgs/sshrm {};
in
{
 
 imports = [
   ./modules/common/cli-packages.nix
   ./modules/common/config.nix
 ];

 home.username = "minegame";
 home.homeDirectory = "/home/minegame";

 home.stateVersion = "24.05"; # Please read the comment before changing.
}

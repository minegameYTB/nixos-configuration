{ lib, config, pkgs, pkgsExtra, ... }:

{
 imports = [
   ### Declare all modules (on all sections)
   ./programs

   ### Add other section here with a default.nix to enumerate all modules
 ];
}

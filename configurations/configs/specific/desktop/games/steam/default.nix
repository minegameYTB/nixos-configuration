{ config, pkgsExtra, ... }:

{
 ### Steam (already provide steam-run (unfree))
 programs.steam = {
   enable = true;
   package = pkgsExtra.pkgs-unstable.steam;
   extraCompatPackages = [
     pkgsExtra.pkgs-unstable.proton-ge-bin
   ];
 };
}

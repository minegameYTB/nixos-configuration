{ config, pkgs, inputs, ... }:

{
 ### Import nix-flatpak like an expression
 imports = [ inputs.declarative-flatpak.nixosModule ];

 ### Declarative flatpak settings
 services.flatpak = {
   enable = true;
   remotes = {
     "flathub" = "https://flathub.org/repo/flathub.flatpakrepo";
   };
   packages = [
     ### Argument order (to see commit, do "flatpak info software")
   # {remote}:{type}/{ref}/[{arch}]/{branch}[:{commit}]
     "flathub:app/io.github.shiftey.Desktop//stable"
     "flathub:app/io.mrarm.mcpelauncher//stable"
     #"com.usebottles.bottles"
   ];
 };
 
 ### Enable xdg portal
  xdg.portal.enable = true;
}

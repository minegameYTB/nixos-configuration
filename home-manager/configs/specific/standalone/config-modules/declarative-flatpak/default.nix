{ config, pkgs, inputs, ... }:

{
 ### Import nix-flatpak like an expression
 imports = [ inputs.declarative-flatpak.homeModule ];

 ### Define flatpak environment variable
 home.sessionVariables = {
   XDG_DATA_DIRS = "$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$XDG_DATA_DIRS";
 };

 ### Declarative flatpak settings
 home.packages = with pkgs; [ flatpak ];

 services.flatpak = {
   enable = true;
   remotes = {
     "flathub" = "https://flathub.org/repo/flathub.flatpakrepo";
   };
   packages = [
     "flathub:app/io.github.shiftey.Desktop//stable"
     "flathub:app/io.mrarm.mcpelauncher//stable"
     #"com.usebottles.bottles"
   ];
 };
}

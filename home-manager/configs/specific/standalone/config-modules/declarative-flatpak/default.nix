{ config, pkgs, inputs, ... }:

{
 ### Import nix-flatpak like an expression
 imports = [ inputs.declarative-flatpak.homeModule ];

 ### Define flatpak environment variable
 home.sessionVariables = {
   XDG_DATA_DIRS = "$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$XDG_DATA_DIRS";
 };

 ### Declarative flatpak settings (do a script to install it automatically system side (with normal package manager))
 services.flatpak = {
   enable = true;
   remotes = {
     "flathub" = "https://flathub.org/repo/flathub.flatpakrepo";
   };
   packages = [
     ### Argument order (to see commit, do "flatpak info software")
     ### Search package with this command (for all used info)
   # {remote}:{type}/{ref}/[{arch}]/{branch}[:{commit}]

     "flathub:app/io.github.shiftey.Desktop//stable"
     "flathub:app/io.mrarm.mcpelauncher//stable"
     #"flathub:app/com.spotify.Client//stable"
     #"com.usebottles.bottles"
   ];
 };
}

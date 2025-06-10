{ config, pkgs, inputs, ... }:

{
 ### Import nix-flatpak like an expression
 imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

 ### Flatpak (extended option with nix-flatpak module)
 services.flatpak = {
   enable = true;

   ### nix-flatpak part
   remotes = [
     {
       name = "flathub";
       location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
     }
     ### Other flatpakref repo here
   ];
   packages = [
     #"io.github.shiftey.Desktop"
     "io.mrarm.mcpelauncher"
     #"com.usebottles.bottles"
   ];
   uninstallUnmanaged = true;
   update = {
     onActivation = false;
     auto = {
       enable = true;
       onCalendar = "weekly";
     };
   };
   overrides = {
     global = {
     # Force Wayland by default
     Context.sockets = ["wayland" "!x11" "!fallback-x11"];

       Environment = {
         # Fix un-themed cursor in some Wayland apps
         XCURSOR_PATH = "/run/host/user-share/icons:/run/host/share/icons";

         # Force correct theme for some GTK apps
         GTK_THEME = "Adwaita:dark";
       };
     };
   };
 };

 xdg.portal.enable = true;
}

{ config, pkgs, pkgsExtra, zen-browser, ... }:

{
 # Home Manager needs a bit of information about you and the paths it should
 # manage.
 home = {
   username = "minegame";
   homeDirectory = "/home/minegame";
 };

 home.packages = 
   (with pkgs; [
     ### non-free apps
     vesktop 

     ### Audio
     amberol
     spotify

     ### Video
     vlc

     ### Office
     onlyoffice-bin

     ### Editor

     ### Games 
     prismlauncher

     ### Utilities
     rpi-imager
     gnome-extension-manager
     bottles
     bitwarden-desktop
  ])
 ++
  (with pkgsExtra.pkgs-23-11; [
    citra
  ]);

}

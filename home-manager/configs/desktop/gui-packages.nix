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
     discord 

     ### Audio
     amberol
     spotify

     ### Video
     vlc

     ### Office
     onlyoffice-bin

     ### Games
     prismlauncher

     ### Utilities
     rpi-imager
     gnome-extension-manager
     bottles
     bitwarden-desktop

     ### Emulator
     melonDS
  ])
 ++
  (with pkgsExtra.pkgs-23-11; [
    ### Emulator
    citra
  ]);

}

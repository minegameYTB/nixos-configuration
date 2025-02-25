{ config, pkgs, ... }:

{
 # Home Manager needs a bit of information about you and the paths it should
 # manage.
 home = {
   username = "minegame";
   homeDirectory = "/home/minegame";
 };

 ### Install theme on home directory
 home.file = {
   ### Ghostty
   ".config/ghostty/config".source = ../../dotfiles/ghostty/config
 };
 
}

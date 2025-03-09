{ config, pkgs, ... }:

{
 # Home Manager needs a bit of information about you and the paths it should
 # manage.
 home = {
   username = "minegame";
   homeDirectory = "/home/minegame";
 };

 home.packages = with pkgs; [
   ### Theme
   adw-gtk3
   catppuccin-cursors.mochaDark
 ];

 ### Install theme on home directory
 home.file = {
   #".themes".source = ../../dotfiles/themes;
   ".icons".source =  ../../dotfiles/icons;
 };
 
}

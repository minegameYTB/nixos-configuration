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

 ### Import conf file for cli software
 home.file = {
   ".screenrc".source = ../../dotfiles/screenrc;
   ".config/fastfetch".source = ../../dotfiles/fastfetch;
 };
 
}

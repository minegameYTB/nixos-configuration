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
   papirus-icon-theme
   ayu-theme-gtk
   catppuccin-cursors.mochaDark
   nur.repos.minegameYTB.theme.marble-shell
 ];

 ### Install theme on home directory
 home.file = {
   ".themes".source = ../../dotfiles/config-file/themes;
   ".config/gtk-4.0".source = ../../dotfiles/config-file/themes/Nightfox-Dark-Carbon/gtk-4.0;
  #".icons".source =  ../../dotfiles/config-file/icons;
 };
}

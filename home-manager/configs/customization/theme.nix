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
   #".themes".source = ../../dotfiles/config-file/themes;
   ".icons".source =  ../../dotfiles/config-file/icons;
   
   ### Backgrounds
   ".local/share/backgrounds/2024-12-19-01-38-51-20240828_115530.jpg".source = ../../dotfiles/backgrounds/2024-12-19-01-38-51-20240828_115530.jpg;
   ".local/share/backgrounds/moon-fall.png".source = ../../dotfiles/backgrounds/moon-fall.png;
   ".local/share/backgrounds/Cherish.png".source = ../../dotfiles/backgrounds/moon-fall.png;
   ".local/share/backgrounds/Archcraft-macchiato.png".source = ../../dotfiles/backgrounds/moon-fall.png;
 };
 
}

{ config, pkgs, ... }:

{
 home.packages = with pkgs; [
   ### Theme
   adw-gtk3
   papirus-icon-theme
   
   ### This theme provide adwaita-dark theme (old theme)
   ayu-theme-gtk
   
   ### From my nurpkgs repo
   nur.repos.minegameYTB.theme.marble-shell-filled
 ];

 ### Set directly the nightfox theme as a gtk4 theme
 #xdg.configFile = {
 #  "gtk-4.0".source = ../../dotfiles/config-file/themes/Tokyonight-Dark/gtk-4.0;
 #};

 ### Install theme on home directory
 home.file = {
  #".themes".source = ../../dotfiles/config-file/themes;
  #".config/gtk-4.0".source = ../../dotfiles/config-file/themes/Nightfox-Dark-Carbon/gtk-4.0;
  #".icons".source =  ../../dotfiles/config-file/icons;
 };
}

{ config, pkgs, ... }:

{
 home.packages = with pkgs; [
   ### Theme
   adw-gtk3
   ### need to move papirus-icon-theme to global config -> specific -> desktop -> gnome.nix
   (papirus-icon-theme.override { color = "green";})
   
   ### Cursor
   ### same for cursor (move this to stylix configuration too)
   catppuccin-cursors.mochaDark

   ### This theme provide adwaita-dark theme (old theme)
   ayu-theme-gtk
   
   ### From my nurpkgs repo
   nur.repos.minegameYTB.theme.marble-shell-filled
 ];

 ### Install theme on home directory
 home.file = {
  #".themes".source = ../../dotfiles/config-file/themes;
  #".config/gtk-4.0".source = ../../dotfiles/config-file/themes/Nightfox-Dark-Carbon/gtk-4.0;
  #".icons".source =  ../../dotfiles/config-file/icons;
 };
}

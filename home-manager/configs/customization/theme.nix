{ config, pkgs, ... }:

{
  ### Unused for the moment
  #home.packages = with pkgs; [
  #  ### Theme
  #  adw-gtk3
  #
  #  ### Cursor
  #  ### same for cursor (move this to stylix configuration too)
  #  catppuccin-cursors.mochaDark
  #];

  ### Install theme on home directory
  home.file = {
    #".themes".source = ../../dotfiles/config-file/themes;
    #".config/gtk-4.0".source = ../../dotfiles/config-file/themes/Nightfox-Dark-Carbon/gtk-4.0;
    #".icons".source =  ../../dotfiles/config-file/icons;
  };
}

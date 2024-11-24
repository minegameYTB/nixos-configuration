{ config, pkgs, ...  }:

{
 ### Gnome Extensions
  environment.systemPackages = with pkgs.gnomeExtensions; [
    appindicator
    tiling-assistant
    dash-to-dock
    blur-my-shell
    logo-menu
    just-perfection
    hide-activities-button
  ];

 ### Exclude some Gnome default packages
 environment.gnome.excludePackages = with pkgs; [
   geary             ### Geary
   gnome-tour        ### Gnome Tour
   epiphany          ### Gnome Web
   gnome-console     ### Gnome console
   yelp              ### Gnome help
   gnome-maps        ### Gnome maps
   gnome-connections ### Gnome connections
 ];

###-------------------------------------------------------------------------

 ### Dconf settings
 programs.dconf = {
   enable = true;
   profiles.user.databases = [
     {
       settings = {
         "org/gnome/desktop/wm/preferences" = {
          button-layout = ":minimize,maximize,close";
        };
         "org/gnome/mutter" = {
          attach-modal-dialogs = true;
        };
         "org/gnome/desktop/interface" = {
          clock-show-date = true;
        };
         "org/gnome/shell/extensions/dash-to-dock" = {
          dock-position = "LEFT";
          transparency-mode = "DYNAMIC";
          running-indicator-style = "DOTS";
          running-indicator-dominant-color = true;
          custom-background-color = true;
          background-color  = "rgb(36,31,49)";
          dash-max-icon-size = "30";
        };
         "org/gnome/shell/extensions/Logo-menu" = {
          hide-forcequit = true;
          hide-softwarecentre = true;
          menu-button-icon-image = "23";
          menu-button-terminal = "kgx";
          symbolic-icon = true;
        };
         "org/gnome/shell/extensions/just-perfection" = {
          theme = true;
          window-demands-attention-focus = true;
        };
       };
     }
   ];
 };

}

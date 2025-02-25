{ config, pkgs, ...  }:

{
 ### Import plymouth.nix expression
 imports = [ ./plymouth.nix ];
 
 ### Gnome Extensions
  environment.systemPackages = with pkgs.gnomeExtensions; [
   appindicator
   tiling-assistant
   dash-to-dock
   blur-my-shell
   logo-menu
   just-perfection
   hide-activities-button
   hibernate-status-button
  ];

 ### Exclude some Gnome default packages
 environment.gnome.excludePackages = with pkgs; [
   geary             ### Geary
   gnome-tour        ### Gnome Tour
   epiphany          ### Gnome Web
   yelp              ### Gnome help
   gnome-maps        ### Gnome maps
   gnome-connections ### Gnome connections
   gnome-console     ### Gnome console (default term)
 ];


 ### Nautilus settings
 programs.nautilus-open-any-terminal = {
   enable = true;
   terminal = "ghostty";
 };

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
            dynamic-workspaces = true;
            edge-tiling = true;
         };
         "org/gnome/desktop/interface" = {
            clock-show-weekday = true;
            clock-show-date = true;
            color-scheme = "prefer-dark";
            gtk-theme = "Adwaita-dark";
            icon-theme = "Papirus-Dark";
            show-battery-percentage = true;
         };
         "org/gnome/shell/extensions/blur-my-shell/application" = {
           whitelist = [
             "com.mitchellh.ghostty"
           ];
         };
         "org/gnome/shell/extensions/dash-to-dock" = {
            dock-position = "LEFT";
            transparency-mode = "DYNAMIC";
            running-indicator-style = "DOTS";
            running-indicator-dominant-color = true;
            custom-background-color = true;
            background-color  = "rgb(36,31,49)";
            dash-max-icon-size = "30";
            custom-theme-shrink = true;
            click-action = "minimize-or-previews";  
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
         "org/gnome/shell" = {
           enabled-extensions = [
             "appindicatorsupport@rgcjonas.gmail.com" 
             "blur-my-shell@aunetx" 
             "dash-to-dock@micxgx.gmail.com" 
             "just-perfection-desktop@just-perfection" 
             "Hide_Activities@shay.shayel.org" 
             "logomenu@aryan_k"
             "user-theme@gnome-shell-extensions.gcampax.github.com" 
             "tiling-assistant@leleat-on-github"
           ];
           favorite-apps = [
             "io.github.zen_browser.zen.desktop" 
             "org.gnome.Calendar.desktop" 
             "org.gnome.Nautilus.desktop" 
             "org.gnome.Software.desktop" 
             "com.mitchellh.ghostty.desktop" 
             "virt-manager.desktop"
             "org.prismlauncher.PrismLauncher.desktop"
             "spotify.desktop" 
             "vesktop.desktop" 
             "steam.desktop"
             "LocalSend.desktop"
           ];
         };
         "org/gnome/nautilus/preferences" = {
           show-create-link = true;
           show-delete-permanently = true;
         };
         "org/gnome/TextEditor" = {
           restore-session = false;
         };
       };
     }
   ];
 };
}

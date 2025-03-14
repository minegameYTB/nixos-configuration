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
   geary                ### Geary
   gnome-tour           ### Gnome Tour
   epiphany             ### Gnome Web
   yelp                 ### Gnome help
   totem                ### Gnome Totem (video)
   gnome-maps           ### Gnome maps
   gnome-connections    ### Gnome connections
   gnome-console        ### Gnome console (default term)
   gnome-music          ### Gnome Music
   gnome-system-monitor ### Gnome system monitor
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
         "org/gnome/shell/extensions/blur-my-shell/applications" = {
           blur = true;
           brightness = "0.8";
           dynamic-opacity = false;
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
	    intellihide-mode = "ALL_WINDOWS";
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
	 "org/gnome/shell/extensions/user-theme" = {
           name = "Marble-red-dark-filled";
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
             "discord.desktop" 
             "steam.desktop"
             "LocalSend.desktop"
           ];
         };
	 ### Declare custom keybind (and their numbers)
         "org/gnome/settings-daemon/plugins/media-keys" = {
           custom-keybindings = [
             "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
	     "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/" 
	     "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/" 
	     "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
	   ];
	 };
	 ### Add custom keybind
	 "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
           binding = "<Control><Alt>t";
	   command = "ghostty";
	   name = "Terminal";
	 };
	 "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
           binding = "<Shift><Control>Escape";
           command = "missioncenter";
           name = "Gestionnaire de tâche";
         };
         "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
           binding = "<Super>e";
           command = "nautilus -w";
           name = "Gestionnaire de fichier";
         };
	 "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
           binding = "<Super>i";
           command = "gnome-control-center";
           name = "Paramètres";
         };
	 ### End of custom keybind
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

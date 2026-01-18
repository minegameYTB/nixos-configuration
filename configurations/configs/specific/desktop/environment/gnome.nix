{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Import desktop related expression
  imports = [ ../desktop.nix ];

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  ### Gnome pinentry gpg
  programs.gnupg.agent = {
    pinentryPackage = lib.mkDefault pkgs.pinentry-gnome3;
  };

  ### Gnome specific packages
  environment.systemPackages =
    (with pkgs; [
      ### Other gnome related packages
      virt-viewer
      mission-center
      gnome-tweaks
      gnome-extension-manager
      evolution
      xarchiver
      amberol
      pika-backup

      ### Themes
      ### Override papirus-icon-theme to set folder color (see other available color here: https://github.com/costales/folder-color/?tab=readme-ov-file#create-a-new-theme)
      (papirus-icon-theme.override { color = "grey"; })

      ### Gtk theme
      adw-gtk3

      ### From my nurpkgs repo
      nur.repos.minegameYTB.theme.marble-shell-filled # Theme
      nur.repos.minegameYTB.gsettings-diff # Tools
    ])
    ++ (with pkgs.gnomeExtensions; [
      ### Extensions
      appindicator
      user-themes
      tiling-assistant
      dash-to-dock
      blur-my-shell
      logo-menu
      hide-activities-button
      clipboard-history
      no-overview
      quick-settings-audio-panel
      grand-theft-focus
      caffeine
    ]);

  ### Exclude some Gnome default packages
  environment.gnome.excludePackages = with pkgs; [
    geary # Geary
    gnome-tour # Gnome Tour
    epiphany # Gnome Web
    #yelp # Gnome help
    totem # Gnome Totem (video)
    gnome-maps # Gnome maps
    gnome-connections # Gnome connections
    gnome-console # Gnome console (default term)
    gnome-music # Gnome Music
    gnome-system-monitor # Gnome system monitor
    gnome-software # Gnome software
  ];

  ### Disable gnome-inital-setup package
  services.gnome.gnome-initial-setup.enable = false;

  ### Disable some services
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  ### xdg mime (fix neovim association)
  xdg.mime.defaultApplications = {
    "text/plain" = "org.gnome.TextEditor.desktop";
    "application/x-shellscript" = "org.gnome.TextEditor.desktop";
  };

  ### Dconf settings
  programs.dconf = {
    enable = true;
    profiles = {
      gdm.databases = [
        {
          settings = {
            "org/gnome/desktop/peripherals/keyboard" = {
              numlock-state = true;
            };
          };
        }
      ];
      user.databases = [
        {
          settings = {
            "org/gnome/desktop/wm/preferences" = {
              button-layout = ":minimize,maximize,close";
            };

            "org/gnome/mutter" = {
              attach-modal-dialogs = true;
              center-new-windows = true;
              dynamic-workspaces = true;
              edge-tiling = true;
            };

            "org/gnome/desktop/interface" = {
              clock-show-weekday = true;
              clock-show-date = true;
              color-scheme = "prefer-dark";
              gtk-theme = "adw-gtk3-dark";
              icon-theme = "Papirus-Dark";
              show-battery-percentage = true;
            };

            "org/gnome/shell/app-switcher" = {
              current-workspace-only = true;
            };

            "org/gnome/shell/extensions/blur-my-shell" = {
              hacks-level = lib.gvariant.mkInt32 2;
            };

            "org/gnome/shell/extensions/blur-my-shell/panel" = {
              static-blur = false;
            };

            "org/gnome/shell/extensions/blur-my-shell/applications" = {
              blur = true;
              brightness = "0.8";
              opacity = lib.gvariant.mkInt32 245;
              dynamic-opacity = false;
              whitelist = [ "com.mitchellh.ghostty" ];
            };

            "org/gnome/shell/extensions/dash-to-dock" = {
              dock-position = "LEFT";
              transparency-mode = "DYNAMIC";
              running-indicator-style = "DOTS";
              running-indicator-dominant-color = true;
              custom-background-color = true;
              background-color = "rgb(36,31,49)";
              dash-max-icon-size = lib.gvariant.mkInt32 30;
              custom-theme-shrink = true;
              click-action = "minimize-or-previews";
              intellihide-mode = "ALL_WINDOWS";
            };

            "org/gnome/shell/extensions/Logo-menu" = {
              hide-forcequit = true;
              hide-softwarecentre = true;
              menu-button-icon-image = lib.gvariant.mkInt32 23;
              menu-button-terminal = "ghostty";
              symbolic-icon = true;
            };

            "org/gnome/shell/extensions/user-theme" = {
              name = "Marble-red-dark-filled";
            };

            "org/gnome/shell/extensions/clipboard-history" = {
              cache-only-favorites = true;
              window-width-percentage = lib.gvariant.mkInt32 28;
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
                "clipboard-history@alexsaveau.dev"
                "no-overview@fthx"
                "quick-settings-audio-panel@rayzeq.github.io"
                "grand-theft-focus@zalckos.github.com"
                "caffeine@patapon.info"
              ];
              favorite-apps = [
                "zen-beta.desktop"
                "org.gnome.Calendar.desktop"
                "org.gnome.Nautilus.desktop"
                "com.mitchellh.ghostty.desktop"
                "virt-manager.desktop"
                "org.prismlauncher.PrismLauncher.desktop"
                "discord.desktop"
                "deezer-enhanced.desktop"
                "steam.desktop"
                "LocalSend.desktop"
              ];
            };

            ### Custom keybinds
            "org/gnome/settings-daemon/plugins/media-keys" = {
              custom-keybindings = [
                "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
                "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
                "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
                "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
              ];
            };

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

            ### App Folders configuration
            "org/gnome/desktop/app-folders" = {
              folder-children = [
                "accessories"
                "chrome-apps"
                "games"
                "graphics"
                "internet"
                "office"
                "programming"
                "science"
                "sound---video"
                "system-tools"
                "universal-access"
                "wine"
                "waydroid"
                "education"
              ];
            };

            "org/gnome/desktop/app-folders/folders/accessories" = {
              name = "Accessories";
              categories = [ "Utility" ];
            };

            "org/gnome/desktop/app-folders/folders/chrome-apps" = {
              name = "Chrome Apps";
              categories = [ "chrome-apps" ];
            };

            "org/gnome/desktop/app-folders/folders/games" = {
              name = "Games";
              categories = [ "Game" ];
            };

            "org/gnome/desktop/app-folders/folders/graphics" = {
              name = "Graphics";
              categories = [ "Graphics" ];
            };

            "org/gnome/desktop/app-folders/folders/internet" = {
              name = "Internet";
              categories = [
                "Network"
                "WebBrowser"
                "Email"
              ];
            };

            "org/gnome/desktop/app-folders/folders/office" = {
              name = "Office";
              categories = [ "Office" ];
            };

            "org/gnome/desktop/app-folders/folders/programming" = {
              name = "Programming";
              categories = [ "Development" ];
            };

            "org/gnome/desktop/app-folders/folders/science" = {
              name = "Science";
              categories = [ "Science" ];
            };

            "org/gnome/desktop/app-folders/folders/sound---video" = {
              name = "Sound & Video";
              categories = [
                "AudioVideo"
                "Audio"
                "Video"
              ];
            };

            "org/gnome/desktop/app-folders/folders/system-tools" = {
              name = "System Tools";
              categories = [
                "System"
                "Settings"
              ];
            };

            "org/gnome/desktop/app-folders/folders/universal-access" = {
              name = "Universal Access";
              categories = [ "Accessibility" ];
            };

            "org/gnome/desktop/app-folders/folders/wine" = {
              name = "Wine";
              categories = [
                "Wine"
                "X-Wine"
                "Wine-Programs-Accessories"
              ];
            };

            "org/gnome/desktop/app-folders/folders/waydroid" = {
              name = "Waydroid";
              categories = [ "X-WayDroid-App" ];
            };

            "org/gnome/desktop/app-folders/folders/education" = {
              name = "Languages & Education";
              categories = [
                "Languages"
                "Education"
              ];
            };

            "org/gnome/nautilus/preferences" = {
              show-create-link = true;
              show-delete-permanently = true;
            };

            "org/gnome/TextEditor" = {
              restore-session = false;
              custom-font = "Adwaita Mono 10";
              use-system-font = false;
            };
          };
        }
      ];
    };
  };

}

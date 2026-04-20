{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Import desktop related expression
  imports = [
    ../desktop.nix
    ./dconf.nix
  ];

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
      refine
      gnome-extension-manager
      #evolution
      thunderbird
      #xarchiver
      file-roller
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
      bluetooth-battery-meter
    ]);

  ### Exclude some Gnome default packages
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour # Gnome Tour
    epiphany # Gnome Web
    #totem # Gnome Totem (video)
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

  ### Overlays some gnome package
  nixpkgs.overlays = [
    (self: super: {
      # Add gstreamer dependancy to nautilus package
      nautilus = super.nautilus.overrideAttrs (oldAttrs: {
        buildInputs =
          oldAttrs.buildInputs or [ ]
          ++ (with super.gst_all_1; [
            gst-plugins-good
            gst-plugins-bad
          ]);
      });

      ### disable extensions_app option on gnome-shell
      gnome-shell = super.gnome-shell.overrideAttrs (oldAttrs: {
        mesonFlags = oldAttrs.mesonFlags or [ ] ++ [ "-Dextensions_app=false" ];
      });
    })
  ];
}

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

  # Enable gnome-keyring (required for autologin + password management)
  services.gnome.gnome-keyring.enable = true;

  # Enable pam_gnome_keyring.so in login and gdm-autologin PAM stacks
  security.pam.services.login.enableGnomeKeyring = true;

  # Default session for GDM (required for autologin to work)
  services.displayManager.defaultSession = "gnome";

  ### KDE connect integration
  programs.kdeconnect = {
    enable = true;
    package = pkgs.gnomeExtensions.gsconnect;
  };

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
      thunderbird
      file-roller
      #amberol
      #pika-backup

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
      gsconnect
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

  ### GNOME Remote Desktop (system RDP/screencast daemon) is mkDefault-enabled
  ### by the GNOME module — disabled: unused attack surface on a local-only
  ### desktop (screen sharing/RDP reachable otherwise).
  services.gnome.gnome-remote-desktop.enable = false;

  ### xdg mime (fix neovim association)
  xdg.mime.defaultApplications = {
    "text/plain" = "org.gnome.TextEditor.desktop";
    "application/x-shellscript" = "org.gnome.TextEditor.desktop";
    "application/x-iso9660-image" = "gnome-disk-image-mounter.desktop";
    "application/octet-stream" = "gnome-disk-image-mounter.desktop";
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

      ### blur-my-shell v77 — native fix for rounded corners on popups
      ### (Quick Settings). The square-corner regression was introduced in
      ### v74 (blur-my-shell#1052) and fixed upstream by PR #976 in v76, which
      ### also deprecated the gnome-rounded-blur library: installing that
      ### library is now useless and only triggers a legacy notice in the
      ### extension preferences. nixpkgs still ships v75, hence the override.
      ###
      ### Reuses buildGnomeExtension's .override, so extensionUuid keeps being
      ### exposed (dconf.nix relies on it). "metadata" pins the EGO-generated
      ### metadata.json, which fetchzip substitutes post-download to keep the
      ### fixed-output derivation deterministic (EGO regenerates that file over
      ### time without bumping the version).
      gnomeExtensions = super.gnomeExtensions // {
        blur-my-shell = super.gnomeExtensions.blur-my-shell.override {
          version = 77;
          sha256 = "1g7xqs4mcayragrrdq1fldr462bjyigfwspqlmracvmrk9m1q6rb";
          metadata = "ewogICJfZ2VuZXJhdGVkIjogIkdlbmVyYXRlZCBieSBTd2VldFRvb3RoLCBkbyBub3QgZWRpdCIsCiAgImRlc2NyaXB0aW9uIjogIkFkZHMgYSBibHVyIGxvb2sgdG8gZGlmZmVyZW50IHBhcnRzIG9mIEdOT01FIFNoZWxsLCBpbmNsdWRpbmcgdGhlIHRvcCBwYW5lbCwgZGFzaCBhbmQgb3ZlcnZpZXcuXG5cbk5vdGU6IGlmIHRoZSBleHRlbnNpb24gc2hvd3MgYW4gZXJyb3IgYWZ0ZXIgdXBkYXRpbmcsIHJlc3RhcnQgeW91ciBzZXNzaW9uIHRvIHNlZSB3aGV0aGVyIGl0IHBlcnNpc3RzLiBUaGlzIGlzIGR1ZSB0byBhIEdOT01FIFNoZWxsIGJ1ZyB0aGF0IHRoZSBleHRlbnNpb24gY2Fubm90IHdvcmsgYXJvdW5kLiIsCiAgImRvbmF0aW9ucyI6IHsKICAgICJnaXRodWIiOiAiYXVuZXR4IiwKICAgICJrb2ZpIjogImF1bmV0eCIKICB9LAogICJnZXR0ZXh0LWRvbWFpbiI6ICJibHVyLW15LXNoZWxsQGF1bmV0eCIsCiAgIm5hbWUiOiAiQmx1ciBteSBTaGVsbCIsCiAgIm9yaWdpbmFsLWF1dGhvcnMiOiBbCiAgICAibWVAYXVuZXR4LmRldiIKICBdLAogICJzZXNzaW9uLW1vZGVzIjogWwogICAgInVubG9jay1kaWFsb2ciLAogICAgInVzZXIiCiAgXSwKICAic2V0dGluZ3Mtc2NoZW1hIjogIm9yZy5nbm9tZS5zaGVsbC5leHRlbnNpb25zLmJsdXItbXktc2hlbGwiLAogICJzaGVsbC12ZXJzaW9uIjogWwogICAgIjQ2IiwKICAgICI0NyIsCiAgICAiNDgiLAogICAgIjQ5IiwKICAgICI1MCIsCiAgICAiNTEiCiAgXSwKICAidXJsIjogImh0dHBzOi8vZ2l0aHViLmNvbS9hdW5ldHgvYmx1ci1teS1zaGVsbCIsCiAgInV1aWQiOiAiYmx1ci1teS1zaGVsbEBhdW5ldHgiLAogICJ2ZXJzaW9uIjogNzcKfQ==";
        };
      };
    })
  ];
}

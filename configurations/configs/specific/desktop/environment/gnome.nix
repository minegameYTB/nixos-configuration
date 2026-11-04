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
      global-menu
    ])
    ### Companion daemon of the global-menu extension: the extension spawns
    ### `global-menu` off the session PATH when an app exports a menu over
    ### D-Bus (see pkgs/global-menu/default.nix).
    ++ [ pkgs.pkgsConfig.global-menu ];

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

      ### disable extensions_app option on gnome-shell
      gnome-shell = super.gnome-shell.overrideAttrs (oldAttrs: {
        mesonFlags = oldAttrs.mesonFlags or [ ] ++ [ "-Dextensions_app=false" ];
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

        ### Global Menu (EGO 11414) — not in nixpkgs yet. uuid
        ### global-menu@unmade.space, repo Unmade760/orbit-global-menu.
        ### `version` is EGO's file version (the download URL is
        ### extension-data/global-menuunmade.space.v5.shell-extension.zip);
        ### the extension's own version-name is 1.1.4 (shell 48-51, we ship
        ### shell 50). `metadata` pins the EGO-generated metadata.json for the
        ### same determinism reason as blur-my-shell above — regenerate with
        ### `base64 -w0 metadata.json` from that zip. sha256 comes from
        ### `nix-prefetch-url --unpack` (the zip is flat, so it matches
        ### fetchzip with stripRoot = false).
        ### French translation: the EGO zip only ships zh_CN, so compile
        ### ./po/fr.po ourselves (159 messages, extension UI only — the
        ### shortcut-menu JSON labels come from files, not gettext). The
        ### metadata's gettext-domain is "global-menu", which GNOME Shell
        ### binds to <ext>/locale at load; `--check` revalidates the format
        ### strings on every build, so a stale po fails loudly.
        global-menu =
          (super.gnomeExtensions.buildShellExtension {
            pname = "global-menu";
            name = "Global Menu";
            uuid = "global-menu@unmade.space";
            version = 5;
            link = "https://extensions.gnome.org/extension/11414/global-menu/";
            description = ''
              A menu bar for GNOME. The focused application's menus appear in the top panel.

              It tries three sources in order: the menu the application exports over D-Bus, then a curated menu that fires the application's own keyboard shortcuts, then a generic window and system menu.

              Reading a menu an application exports needs the companion global-menu daemon, installed separately.
            '';
            sha256 = "03a8q8ybv1dqnw95187gwzf9nnd4ws7jdkx1zi9sqpn1rz2p58x0";
            metadata = "ewogICJfZ2VuZXJhdGVkIjogIkdlbmVyYXRlZCBieSBTd2VldFRvb3RoLCBkbyBub3QgZWRpdCIsCiAgImRlc2NyaXB0aW9uIjogIkEgbWVudSBiYXIgZm9yIEdOT01FLiBUaGUgZm9jdXNlZCBhcHBsaWNhdGlvbidzIG1lbnVzIGFwcGVhciBpbiB0aGUgdG9wIHBhbmVsLlxuXG5JdCB0cmllcyB0aHJlZSBzb3VyY2VzIGluIG9yZGVyOiB0aGUgbWVudSB0aGUgYXBwbGljYXRpb24gZXhwb3J0cyBvdmVyIEQtQnVzLCB0aGVuIGEgY3VyYXRlZCBtZW51IHRoYXQgZmlyZXMgdGhlIGFwcGxpY2F0aW9uJ3Mgb3duIGtleWJvYXJkIHNob3J0Y3V0cywgdGhlbiBhIGdlbmVyaWMgd2luZG93IGFuZCBzeXN0ZW0gbWVudS5cblxuUmVhZGluZyBhIG1lbnUgYW4gYXBwbGljYXRpb24gZXhwb3J0cyBuZWVkcyB0aGUgY29tcGFuaW9uIGdsb2JhbC1tZW51IGRhZW1vbiwgaW5zdGFsbGVkIHNlcGFyYXRlbHkuIiwKICAiZ2V0dGV4dC1kb21haW4iOiAiZ2xvYmFsLW1lbnUiLAogICJuYW1lIjogIkdsb2JhbCBNZW51IiwKICAic2V0dGluZ3Mtc2NoZW1hIjogIm9yZy5nbm9tZS5zaGVsbC5leHRlbnNpb25zLmdsb2JhbC1tZW51IiwKICAic2hlbGwtdmVyc2lvbiI6IFsKICAgICI0OCIsCiAgICAiNDkiLAogICAgIjUwIiwKICAgICI1MSIKICBdLAogICJ1cmwiOiAiaHR0cHM6Ly9naXRodWIuY29tL1VubWFkZTc2MC9vcmJpdC1nbG9iYWwtbWVudSIsCiAgInV1aWQiOiAiZ2xvYmFsLW1lbnVAdW5tYWRlLnNwYWNlIiwKICAidmVyc2lvbiI6IDUsCiAgInZlcnNpb24tbmFtZSI6ICIxLjEuNCIKfQ==";
          }).overrideAttrs
            (old: {
              ### postInstall runs right after installPhase copied the extension
              ### tree into $out; compile the French po where GNOME Shell looks
              ### (<ext>/locale/<lang>/LC_MESSAGES/<gettext-domain>.mo).
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ super.gettext ];
              postInstall = (old.postInstall or "") + ''
                mkdir -p $out/share/gnome-shell/extensions/global-menu@unmade.space/locale/fr/LC_MESSAGES
                msgfmt --check -o $out/share/gnome-shell/extensions/global-menu@unmade.space/locale/fr/LC_MESSAGES/global-menu.mo ${./po/fr.po}
              '';
            });
      };
    })
  ];
}

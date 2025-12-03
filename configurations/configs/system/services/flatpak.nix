{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Flatpak
  #systemd.services.flatpak-repo = {
  #  wantedBy = [ "multi-user.target" ];
  #  requires = [ "network-online.target" ];
  #  after = [ "network-online.target" ];
  #  environment = lib.mkForce {
  #    PATH = "${pkgs.flatpak}/bin";
  #   };
  #  script = ''
  #    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  #  '';
  #};

  ### Flatpak (extended option with nix-flatpak module)
  services.flatpak = {
    enable = true;

    ### nix-flatpak part
    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
      ### Other flatpakref repo here
    ];
    packages = [
      "io.github.shiftey.Desktop"
      "io.mrarm.mcpelauncher"
    ];
    uninstallUnmanaged = true;
    update = {
      onActivation = false;
      auto = {
        enable = true;
        onCalendar = "weekly";
      };
    };
    overrides = {
      global = {

        # Force Wayland by default
        Context.sockets = [
          "wayland"
          "!x11"
          "!fallback-x11"
        ];

        Environment = {
          # Fix un-themed cursor in some Wayland apps
          XCURSOR_PATH = "/run/host/user-share/icons:/run/host/share/icons";

          # Force correct theme for some GTK apps
          GTK_THEME = "Adwaita:dark";
        };
      };
    };
  };

  xdg.portal.enable = true;

  environment.systemPackages = with pkgs; [
    flatpak
  ];
}

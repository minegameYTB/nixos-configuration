{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### XDG portals N1-micro (FileChooser, OpenURI, ScreenCast, Notification)
  ### GNOME gate only — no impact on CLI/servers. Benefits portal-aware native
  ### apps (Firefox/Zen/Vivaldi/Thunderbird, GTK4, Electron) + Flatpak.
  xdg.portal = lib.mkIf config.services.desktopManager.gnome.enable {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
    config = {
      common.default = [ "gtk" ];
      gnome.default = [
        "gnome"
        "gtk"
      ];
    };
  };
}

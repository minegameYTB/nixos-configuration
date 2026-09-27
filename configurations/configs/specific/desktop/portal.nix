{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### XDG portals N1-micro (FileChooser, OpenURI, ScreenCast, Notification)
  ### Gate GNOME only — no impact CLI/serveurs. Profite au natif portal-aware
  ### (Firefox/Zen/Vivaldi/Thunderbird, GTK4, Electron) + Flatpak.
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

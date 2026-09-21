{ config, pkgs, lib, ... }:

{
  ### Autologin via greetd (no display-manager greeter race): GDM's
  ### autologin is broken on this machine in both modes (immediate:
  ### session starts on VT2 but its GDM registration times out, stray
  ### greeter keeps tty1; timed: the autologin conversation stalls
  ### forever) while manual login works. greetd initial_session boots
  ### straight into GNOME deterministically; logout falls back to the
  ### tuigreet menu (session picker + power actions) instead of
  ### re-logging in. Only hp-240 imports this file.
  services.displayManager.gdm.enable = lib.mkForce false;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --asterisks --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions --power-shutdown 'systemctl poweroff' --power-reboot 'systemctl reboot'";
        user = "greeter";
      };
      initial_session = {
        command = "${pkgs.gnome-session}/bin/gnome-session";
        user = "minegame";
      };
    };
  };

  ### Unlock the login keyring in greetd sessions, like GDM does.
  security.pam.services.greetd.enableGnomeKeyring = true;

  ### Set the loginuid so processes map to their logind session
  ### (gnome-shell dies with "no matching session" without it).
  ### Standard for login flows; harmless for the greeter itself.
  security.pam.services.greetd.setLoginUid = true;
}

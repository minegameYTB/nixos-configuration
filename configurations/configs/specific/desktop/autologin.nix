{ config, pkgs, lib, ... }:

let
  ### TEMPORARY diagnostic wrapper: dumps the exact environment
  ### greetd launches initial_session with, runs gnome-session as a
  ### child to capture its exit code, and logs both. Remove once the
  ### 2-second death is understood (keep plain gnome-session after).
  gnome-session-debug = pkgs.writeShellScriptBin "gnome-session-debug" ''
    ${pkgs.coreutils}/bin/env | ${pkgs.coreutils}/bin/sort > /tmp/greetd-initial-env.txt
    ${pkgs.gnome-session}/bin/gnome-session >> /tmp/greetd-initial-env.txt 2>&1
    echo "exit=$?" >> /tmp/greetd-initial-env.txt
  '';
in


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
        command = "${gnome-session-debug}/bin/gnome-session-debug";
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

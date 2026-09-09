{
  lib,
  pkgs,
  config,
  keyboardSetupScript,
  keyboardSessionScript,
  welcomeMessage,
  rev,
  branch,
  edition,
  mkIsoConfig,
  username,
  ...
}:
{
  imports = [
    ../configurations/configs/specific/desktop/environment/gnome.nix
    ../configurations/configs/specific/desktop/sound.nix
    ../configurations/configs/specific/desktop/browser
    ../configurations/hardware-configuration/specific/intel-graphics.nix
    ../configurations/configs/specific/vm/guest/qemu-kvm-guest.nix

    (mkIsoConfig {
      inherit
        edition
        rev
        branch
        welcomeMessage
        keyboardSetupScript
        keyboardSessionScript
        username
        ;
    })
  ];

  marker = {
    hostProfile = "desktop";
    archProfile = "x86-64-v1";
  };

  console.keyMap = "fr";
  services.xserver.xkb.layout = "fr";

  services.xserver.displayManager.lightdm.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = username;
  };

  ### Disable GDM fix autologin bug
  services.displayManager.gdm.enable = lib.mkForce false;

  systemd.user.services.keyboard-session-apply = {
    description = "Re-apply keyboard layout after GNOME session init";
    wantedBy = [ "gnome-session.target" ];
    after = [
      "gnome-session.target"
      "org.gnome.SettingsDaemon.Keyboard.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe keyboardSessionScript}";
    };
  };

  # No auto-suspend/idle on the live ISO (mirrors the official GNOME ISO:
  # installation-cd-graphical-calamares-gnome.nix:22, gdm.nix:340).
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.desktop.session]
    idle-delay=0
    [org.gnome.desktop.screensaver]
    idle-activation-enabled=false
    lock-enabled=false
    [org.gnome.settings-daemon.plugins.power]
    sleep-inactive-ac-type='nothing'
    sleep-inactive-battery-type='nothing'
    sleep-inactive-ac-timeout=0
    sleep-inactive-battery-timeout=0
    idle-dim=false
    [org.gnome.shell]
    welcome-dialog-last-shown-version='9999999999'
  '';
  services.desktopManager.gnome.extraGSettingsOverridePackages = [ pkgs.gnome-settings-daemon ];

  # Same for the GDM greeter profile (harmless under the current LightDM choice).
  services.displayManager.gdm.autoSuspend = lib.mkDefault false;
}

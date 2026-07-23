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
  ...
}:
{
  imports = [
    ../configurations/configs/specific/desktop/environment/gnome.nix
    ../configurations/configs/specific/desktop/sound.nix
    ../configurations/configs/specific/desktop/browser
    ../configurations/configs/specific/vm/guest/qemu-kvm-guest.nix

    (mkIsoConfig {
      inherit
        edition
        rev
        branch
        welcomeMessage
        keyboardSetupScript
        keyboardSessionScript
        ;
    })
  ];

  marker = {
    hostProfile = "desktop";
    archProfile = "x86-64-v1";
  };

  console.keyMap = "fr";
  services.xserver.xkb.layout = "fr";

  services.displayManager.autoLogin = {
    enable = true;
    user = "nixos";
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

  # Prevent screen blanking / sleeping during live ISO use
  systemd.user.services.disable-screen-blanking = {
    description = "Disable screen blanking and idle sleep for the ISO session";
    wantedBy = [ "gnome-session.target" ];
    after = [ "gnome-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "disable-screen-blanking" ''
        ${lib.getExe' pkgs.glib "gsettings"} set org.gnome.desktop.session idle-delay 0
        ${lib.getExe' pkgs.glib "gsettings"} set org.gnome.desktop.screensaver idle-activation-enabled false
        ${lib.getExe' pkgs.glib "gsettings"} set org.gnome.desktop.screensaver lock-enabled false
        ${lib.getExe' pkgs.glib "gsettings"} set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
      ''}";
    };
  };
}

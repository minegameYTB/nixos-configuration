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

    (mkIsoConfig { inherit edition rev branch welcomeMessage keyboardSetupScript keyboardSessionScript; })
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
}

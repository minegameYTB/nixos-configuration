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
    ../configurations/configuration.nix

    ### Desktop environment
    ../configurations/configs/specific/desktop/environment/gnome.nix
    ../configurations/configs/specific/desktop/sound.nix
    ../configurations/configs/specific/desktop/browser

    ### Networking
    ../configurations/configs/networking

    ### Config modules (stylix, flatpak, nix-index-db)
    ../configurations/config-modules

    ### Tmpfs /tmp
    ../configurations/configs/system/tmp-on-tmpfs.nix

    ### Shared ISO config (naming, keyboard, services, etc.)
    (mkIsoConfig { inherit edition rev branch welcomeMessage keyboardSetupScript keyboardSessionScript; })
  ];

  ### marker required by cachyos-kernel.nix and marker.nix assertion
  marker = {
    hostProfile = "desktop";
    archProfile = "x86-64-v1";
  };

  ### Default keyboard — French (fr)
  console.keyMap = "fr";
  services.xserver.xkb.layout = "fr";

  ### Autologin via GDM
  services.displayManager.autoLogin = {
    enable = true;
    user = "nixos";
  };

  ### Keyboard session apply — re-applies layout after GNOME session init
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

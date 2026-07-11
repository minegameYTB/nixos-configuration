{
  lib,
  pkgs,
  config,
  mkKeyboardSpec,
  keyboardSetupScript,
  keyboardSessionScript,
  layouts,
  welcomeMessage,
  ...
}:
{
  ### Import same base modules as a regular machine
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
  ]

  ### Keyboard specialisations (10 layouts)
  ++ map mkKeyboardSpec layouts;

  ### marker required by cachyos-kernel.nix and marker.nix assertion
  marker = {
    hostProfile = "desktop";
    archProfile = "x86-64-v1";
  };

  ### Default locale and keyboard — French (fr)
  i18n.defaultLocale = "fr_FR.UTF-8";
  console.keyMap = "fr";
  services.xserver.xkb.layout = "fr";

  ### Fix conflict between boot-settings.nix (hash) and iso-image.nix (true)
  boot.initrd.systemd.emergencyAccess = lib.mkForce true;

  ### ZFS kernel module incompatible with CachyOS kernel — not needed on live ISO
  boot.supportedFilesystems.zfs = lib.mkForce false;

  ### Override nixos user (created by users.nix via specialArgs users=["nixos"])
  ### to have an empty password for the live ISO
  users.users.nixos.initialPassword = lib.mkForce "";
  users.users.nixos.initialHashedPassword = lib.mkForce null;

  ### Autologin via GDM
  services.displayManager.autoLogin = {
    enable = true;
    user = "nixos";
  };

  ### Disable sleep/hibernate on live ISO
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  ### NetworkManager for live ISO
  networking.networkmanager.enable = true;

  ### SSH for live ISO
  services.openssh.enable = true;

  ### Keyboard setup — applies layout early (console, X11, dconf)
  systemd.services.keyboard-setup = {
    description = "Apply keyboard layout from kernel cmdline";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "local-fs.target" "systemd-vconsole-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe keyboardSetupScript}";
    };
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

  ### Make the config package and keyboard session script available in the live ISO
  environment.systemPackages = [
    pkgs.pkgsConfig.nixos-config
    keyboardSessionScript
  ];

  ### Welcome message
  environment.interactiveShellInit = welcomeMessage;
}

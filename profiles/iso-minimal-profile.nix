{
  lib,
  pkgs,
  config,
  mkKeyboardSpec,
  keyboardSetupScript,
  layouts,
  welcomeMessage,
  ...
}:
{
  ### Import same base modules as a regular machine
  imports = [
    ../configurations/configuration.nix

    ### Networking
    ../configurations/configs/networking

    ### Config modules (stylix, flatpak, nix-index-db)
    ../configurations/config-modules

    ### Tmpfs /tmp
    ../configurations/configs/system/tmp-on-tmpfs.nix
  ]

  ### Keyboard specialisations (10 layouts)
  ++ map mkKeyboardSpec layouts;

  ### marker: server profile → uses cachyos LTS kernel
  marker = {
    hostProfile = "server";
    archProfile = "x86-64-v1";
  };

  ### Default locale and keyboard — French (fr)
  i18n.defaultLocale = "fr_FR.UTF-8";
  console.keyMap = "fr";

  ### Fix conflict between boot-settings.nix (hash) and iso-image.nix (true)
  boot.initrd.systemd.emergencyAccess = lib.mkForce true;

  ### ZFS kernel module incompatible with CachyOS kernel — not needed on live ISO
  boot.supportedFilesystems.zfs = lib.mkForce false;

  ### Override nixos user to have an empty password for the live ISO
  users.users.nixos.initialPassword = lib.mkForce "";
  users.users.nixos.initialHashedPassword = lib.mkForce null;

  ### (CLI ISO: no autologin since there's no display manager)

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

  ### Keyboard setup — applies layout early (console only)
  systemd.services.keyboard-setup = {
    description = "Apply keyboard layout from kernel cmdline";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" "systemd-vconsole-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe keyboardSetupScript}";
    };
  };

  ### Make the config package available in the live ISO
  environment.systemPackages = [
    pkgs.pkgsConfig.nixos-config
  ];

  ### Welcome message
  environment.interactiveShellInit = welcomeMessage;
}

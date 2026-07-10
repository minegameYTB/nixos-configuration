{
  lib,
  pkgs,
  config,
  mkKeyboardSpec,
  keyboardSetupScript,
  ...
}:

let
  ### 10 keyboard layouts: us, de, es, it, pt, gb, be, ch, ca + default fr
  layouts = [
    { layout = "us"; keymap = "us";  locale = "en_US.UTF-8";  label = "US English"; }
    { layout = "de"; keymap = "de";  locale = "de_DE.UTF-8";  label = "German"; }
    { layout = "es"; keymap = "es";  locale = "es_ES.UTF-8";  label = "Spanish"; }
    { layout = "it"; keymap = "it";  locale = "it_IT.UTF-8";  label = "Italian"; }
    { layout = "pt"; keymap = "pt";  locale = "pt_PT.UTF-8";  label = "Portuguese"; }
    { layout = "gb"; keymap = "gb";  locale = "en_GB.UTF-8";  label = "British English"; }
    { layout = "be"; keymap = "be";  locale = "fr_BE.UTF-8";  label = "Belgian"; }
    { layout = "ch"; keymap = "ch";  locale = "de_CH.UTF-8";  label = "Swiss"; }
    { layout = "ca"; keymap = "ca";  locale = "en_CA.UTF-8";  label = "Canadian"; }
    { layout = "fr"; keymap = "fr";  locale = "fr_FR.UTF-8";  label = "French (default)"; }
  ];
in
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

  ### Fix conflict between boot-settings.nix (hash) and iso-image.nix (true)
  boot.initrd.systemd.emergencyAccess = lib.mkForce true;

  ### Override nixos user to have an empty password for the live ISO
  users.users.nixos.initialPassword = lib.mkForce "";

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
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe keyboardSetupScript}";
    };
  };

  ### Make the config package available in the live ISO
  environment.systemPackages = [
    pkgs.pkgsConfig.nixos-config
  ];

  ### Welcome message
  environment.interactiveShellInit = ''
    if [ -z "$_NIXOS_ISO_WELCOME" ]; then
      _NIXOS_ISO_WELCOME=1
      cat <<'WELCOME'
    ╔══════════════════════════════════════════════╗
    ║    NixOS Live ISO — Minimal CLI Edition      ║
    ║                                              ║
    ║  Type: sudo nixos-install                    ║
    ║  Or:   install-nixos                         ║
    ║                                              ║
    ║  Keyboard: select at GRUB menu (e.g. us, de) ║
    ║  User: nixos (no password)                   ║
    ╚══════════════════════════════════════════════╝
    WELCOME
    fi
  '';
}

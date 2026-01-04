{
  lib,
  config,
  pkgs,
  ...
}:

{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.minegame = {
    description = "Minegame YTB";
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "kvm"
      "input"
    ];
    initialPassword = "nixos";
  };

  ### Fix non creation of Desktop...Download folder in graphical mode
  systemd.services."fix-xdg-user-dirs" = {
    enable = config.services.desktopManager.gnome.enable;
    wantedBy = [ "graphical.target" ];
    environment.PATH = lib.mkForce "${pkgs.coreutils}/bin:${pkgs.xdg-user-dirs}/bin";
    serviceConfig = {
      Type = "oneshot";

      ### Run service as the first user created (minegame in my case)
      User = config.users.users.minegame.name;

      ### Hardening service
      ProtectSystem = "strict";
      PrivateTmp = "true";
      NoNewPrivileges = "yes";
    };
    script = ''
      HOME=${config.users.users.minegame.home}
      testFile=$HOME/.xdg-user-dir-done

      ### test if ".xdg-user-dir-done" is created
      if [ -e "$testFile" ]; then
        exit 0
      else
        touch $testFile
      fi

      ### if the file is not detect on the first check, execute the command
      xdg-user-dirs-update
    '';
  };

}

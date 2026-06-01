{
  lib,
  config,
  pkgs,
  users,
  description,
  ...
}:

{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = lib.genAttrs users (username: {
    inherit description;
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "kvm"
      "input"
      "podman" # To use docker socket with podman
    ];
    initialPassword = "nixos";
  });

  ### Fix non creation of Desktop...Download folder in graphical mode
  systemd.services."fix-xdg-user-dirs" =
    let
      username = lib.head (
        lib.filter (u: config.users.users.${u}.isNormalUser or false) (lib.attrNames config.users.users)
      );
    in
    rec {
      enable = config.services.xserver.enable;
      wantedBy = [ "graphical.target" ];
      environment.PATH = lib.mkForce "${pkgs.coreutils}/bin:${pkgs.xdg-user-dirs}/bin";
      serviceConfig = {
        Type = "oneshot";

        ### Run service as the first user created (minegame in my case)
        User = username;

        ### Hardening service
        ProtectSystem = "strict";
        PrivateTmp = "true";
        NoNewPrivileges = "yes";
      };
      script = ''
        HOME=/home/${serviceConfig.User}
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

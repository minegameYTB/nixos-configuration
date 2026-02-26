{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  ### Import lanzaboote like an expression
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  ### Add tools for secureboot and lanzaboote
  environment.systemPackages = with pkgs; [
    # For debugging and troubleshooting Secure Boot.
    sbctl
  ];

  # Lanzaboote currently replaces the systemd-boot module.
  # This setting is usually set to true in configuration.nix
  # generated at installation time. So we force it to false
  # for now.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    autoGenerateKeys.enable = true;
    autoEnrollKeys.enable = true;
  };

  ### Clean .auth files created in /
  systemd.services."cleanup-lanzaboote-auth" = {
    description = "Clean unused new .auth files in /";
    environment = lib.mkForce {
      PATH = "${pkgs.efivar.bin}/bin:${pkgs.coreutils.out}/bin:${pkgs.gawk.out}/bin";
    };
    wantedBy = [ "multi-user.target" ];
    after = [ "efivarfs.mount" ];
    unitConfig.ConditionPathExistsGlob = "/{PK,KEK,db}.auth";
    serviceConfig = {
      User = "root";
      #Type = "oneshot";

      ### Hardening service
      ProtectSystem = "full";
      PrivateTmp = "true";
      PrivateDevices = "true";
      ProtectKernelLogs = "true";
      ProtectKernelModules = "yes";
      ProtectHostname = "true";
      ProtectHome = "true";
      ProtectProc = "invisible";
      PrivateUsers = "true";
      PrivateNetwork = "true";
      PrivateMounts = "true";
      NoNewPrivileges = "yes";
    };
    script = ''
      echo "Cleaning up .auth files..."
      rm -f /PK.auth /KEK.auth /db.auth
      echo "Cleanup done."
    '';
  };
}

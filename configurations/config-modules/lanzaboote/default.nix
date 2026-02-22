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
  systemd.services.cleanup-lanzaboote-auth = {
    description = "Clean unused new .auth files in /";
    environment = lib.mkForce {
      PATH = "${pkgs.efivar.bin}/bin:${pkgs.coreutils.out}/bin:${pkgs.gawk.out}/bin";
    };
    wantedBy = [ "multi-user.target" ];
    after = [ "efivarfs.mount" ];
    unitConfig.ConditionPathExistsGlob = "/{PK,KEK,db}.auth";
    serviceConfig = {
      Type = "oneshot";

      ### Hardening service
      ProtectSystem = "strict";
      PrivateTmp = "true";
      NoNewPrivileges = "yes";
      ReadWritePaths = [
        "/PK.auth"
        "/KEK.auth"
        "/db.auth"
      ];
    };
    script = ''
      SB_FILE=$(ls /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | head -n1)
      SM_FILE=$(ls /sys/firmware/efi/efivars/SetupMode-* 2>/dev/null | head -n1)

      if [ -z "$SB_FILE" ] || [ -z "$SM_FILE" ]; then
        echo "Unable to find SetupMode, Skipping"
        exit 0
      fi

      secureBoot=$(hexdump -v -e '1/1 "%d"' "$SB_FILE" | tail -c 1)
      setupMode=$(hexdump -v -e '1/1 "%d"' "$SM_FILE" | tail -c 1)

      echo "SecureBoot=$secureBoot SetupMode=$setupMode"

      if [ "$secureBoot" = "1" ] && [ "$setupMode" = "0" ]; then
        echo "Provisioning complete. Cleaning up .auth files..."
        rm -f /PK.auth /KEK.auth /db.auth
        echo "Cleanup done."
      else
        echo "Provisioning not complete. Skipping cleanup"
      fi
    '';
  };
}

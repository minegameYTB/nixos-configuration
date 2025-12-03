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
  };
}

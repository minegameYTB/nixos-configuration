{ config, lib, pkgs, ... }:

let
  cfg = config.system.copyFlakeConfiguration;
in {
  options.system.copyFlakeConfiguration = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg {
    system.systemBuilderCommands = ''
      ln -s ${pkgs.pkgsConfig.nixos-config}/share/nixos-config "$out/flake"
    '';
  };
}
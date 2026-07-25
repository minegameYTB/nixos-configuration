{ config, lib, pkgs, ... }:

let
  cfg = config.system.copyFlakeConfiguration;
in {
  options.system.copyFlakeConfiguration = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg {
    system.build.flakeCopy = pkgs.pkgsConfig.nixos-config.overrideAttrs (oldAttrs: {
      name = lib.replaceStrings [ "-dirty" ] [ "" ] "${oldAttrs.pname}-${oldAttrs.version}";
    });

    system.systemBuilderCommands = ''
      ln -s ${config.system.build.flakeCopy}/share/nixos-config "$out/flake"
    '';
  };
}
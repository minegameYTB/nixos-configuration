{ config, lib, pkgs, flakePath, ... }:

let
  cfg = config.system.copyFlakeConfiguration;
in {
  options.system.copyFlakeConfiguration = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg {
    system.build.flakeCopy = pkgs.stdenvNoCC.mkDerivation {
      name = "nixos-flake-copy";
      src = flakePath;
      dontBuild = true;
      installPhase = ''
        mkdir -p $out
        cp -r . "$out/"
        rm -rf "$out/.git"
        rm -f "$out/result" "$out/result-"*
      '';
    };

    system.extraSystemBuilderCmds = ''
      ln -s ${config.system.build.flakeCopy} "$out/flake"
    '';
  };
}

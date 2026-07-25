{ config, lib, pkgs, flakePath, rev, branch, repoUrl, ... }:

let
  cfg = config.system.copyFlakeConfiguration;
in {
  options.system.copyFlakeConfiguration = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg {
    system.build.flakeCopy = pkgs.stdenvNoCC.mkDerivation rec {
      pname = "nixos-config-flake";
      version = "${lib.trivial.release}.${rev}" + lib.optionalString (branch != null) ".${branch}";
      name = "${pname}-${version}";
      src = flakePath;
      dontBuild = true;
      installPhase = ''
        mkdir -p $out
        cp -r . "$out/"
        rm -rf "$out/.git"
        rm -f "$out/result" "$out/result-"*
        echo "${repoUrl} ${lib.removeSuffix "-dirty" rev}" > "$out/.config-repo"
      '';
    };

    system.systemBuilderCommands = ''
      ln -s ${config.system.build.flakeCopy} "$out/flake"
    '';
  };
}

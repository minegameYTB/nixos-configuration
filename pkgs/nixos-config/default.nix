{ stdenvNoCC, lib, src, rev, writeShellScriptBin, runtimeShell, branch ? null }:

stdenvNoCC.mkDerivation rec {
  pname = "nixos-config";
  version = "nixos-configuration.${lib.trivial.release}.${rev}"
    + lib.optionalString (branch != null) ".${branch}";
  dontBuild = true;
  inherit src;

  installPhase = ''
    mkdir -p $out/share/nixos-config $out/bin
    cp -r . $out/share/nixos-config/
    rm -rf $out/share/nixos-config/.git
    rm -f $out/share/nixos-config/result $out/share/nixos-config/result-*
    cp ${writeShellScriptBin "nixos-config-install" ''
      set -euo pipefail
      SELF=$(readlink -f "$0")
      SRC=$(dirname "$SELF")/../share/nixos-config

      echo ""
      echo "═══════════════════════════════════════════════════════════════"
      echo "  NixOS Configuration Installer"
      echo "  Version : ${version}"
      echo ""
      echo "  Run the following command to install the configuration:"
      echo "    sudo ./install.sh"
      echo "═══════════════════════════════════════════════════════════════"
      echo ""

      WORKDIR=$(mktemp -d /tmp/nixos-config-install-XXXX)
      echo "Copying configuration to $WORKDIR ..."
      cp -r "$SRC"/* "$WORKDIR/"
      chmod -R +w "$WORKDIR"
      cd "$WORKDIR"
      exec ${runtimeShell} "$WORKDIR/install.sh" "$@"
    ''}/bin/nixos-config-install $out/bin/nixos-config-install
  '';
}
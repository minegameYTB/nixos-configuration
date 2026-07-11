{ stdenvNoCC, lib, src, rev, writeShellScriptBin, runtimeShell, branch ? null, repoUrl ? null }:

stdenvNoCC.mkDerivation rec {
  pname = "nixos-config";
  version = "${lib.trivial.release}.${rev}"
    + lib.optionalString (branch != null) ".${branch}";
  dontBuild = true;
  inherit src;

  installPhase = ''
    mkdir -p $out/share/nixos-config $out/bin
    cp -r . $out/share/nixos-config/
    rm -rf $out/share/nixos-config/.git
    rm -f $out/share/nixos-config/result $out/share/nixos-config/result-*
    echo "${repoUrl} ${lib.removeSuffix "-dirty" rev}" > $out/share/nixos-config/.config-repo
    cp ${writeShellScriptBin "nixos-config-install" ''
      set -euo pipefail
      SELF=$(readlink -f "$0")
      SRC=$(dirname "$SELF")/../share/nixos-config
      WORKDIR="/tmp/nixos-config-install"
      VERSION_FILE="$WORKDIR/.config-version"

      echo ""
      echo "═══════════════════════════════════════════════════════════════"
      echo "  NixOS Configuration Installer"
      echo "  Version : ${version}"
      echo ""
      echo "  Run the following command to install the configuration:"
      echo "    sudo ./install.sh"
      echo "═══════════════════════════════════════════════════════════════"
      echo ""

      if [ -d "$WORKDIR" ] && [ -f "$VERSION_FILE" ] && [ "$(cat "$VERSION_FILE")" = "${version}" ]; then
        echo "Configuration unchanged, reusing $WORKDIR ..."
      else
        echo "Setting up configuration in $WORKDIR ..."
        rm -rf "$WORKDIR"
        mkdir -p "$WORKDIR"
        cp -r "$SRC"/* "$WORKDIR/"
        chmod -R +w "$WORKDIR"
        echo "${version}" > "$VERSION_FILE"
      fi

      cd "$WORKDIR"
      exec ${runtimeShell} "$WORKDIR/install.sh" "$@"
    ''}/bin/nixos-config-install $out/bin/nixos-config-install
  '';
}
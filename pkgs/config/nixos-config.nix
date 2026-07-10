{ stdenvNoCC, bashInteractive, src, configVersion }:

stdenvNoCC.mkDerivation {
  name = "nixos-config-${configVersion}";
  dontBuild = true;
  inherit src;

  buildInputs = [ bashInteractive ];

  installPhase = ''
    mkdir -p $out/share/nixos-config $out/bin

    cp -r . $out/share/nixos-config/
    rm -rf $out/share/nixos-config/.git

    cat > $out/bin/install-nixos << INSTALLEOF
    #!${bashInteractive}/bin/bash
    set -euo pipefail
    SRC="@configSrc@"
    WORKDIR=\$(mktemp -d /tmp/nixos-install-XXXX)
    cp -r "\$SRC"/* "\$WORKDIR/"
    chmod -R +w "\$WORKDIR"
    echo ""
    echo "══════════════════════════════════════════════════"
    echo "  NixOS Configuration Installer"
    echo "  Version : ${configVersion}"
    echo "══════════════════════════════════════════════════"
    echo ""
    cd "\$WORKDIR"
    exec ${bashInteractive}/bin/bash "\$WORKDIR/install.sh" "\$@"
    INSTALLEOF

    substituteInPlace $out/bin/install-nixos \
      --subst-var-by configSrc "$out/share/nixos-config"
    chmod +x $out/bin/install-nixos
  '';
}

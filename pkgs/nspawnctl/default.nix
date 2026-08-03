{
  stdenvNoCC,
  lib,
  makeWrapper,
  zfs,
  curl,
  jq,
  gnutar,
  xz,
  debootstrap,
  coreutils,
  gnugrep,
  gnused,
  gawk,
  systemd,
  iproute2,
  util-linux,
  pkgsStatic,
}:

stdenvNoCC.mkDerivation {
  pname = "nspawnctl";
  version = "0.3.0";

  src = ./src;

  dontBuild = true;
  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src/nspawnctl $out/bin/nspawnctl
    mkdir -p $out/lib/nspawnctl
    cp $src/lib/*.sh $out/lib/nspawnctl/
    runHook postInstall
  '';

  postFixup = ''
    substituteInPlace $out/bin/nspawnctl \
      --replace '@LIBDIR@' "$out/lib/nspawnctl" \
      --replace '@BUSYBOX@' "${pkgsStatic.busybox}/bin/busybox"
    wrapProgram $out/bin/nspawnctl \
      --set TERM xterm-256color \
      --set PATH ${
        lib.makeBinPath [
          zfs
          curl
          jq
          gnutar
          xz
          debootstrap
          coreutils
          gnugrep
          gnused
          gawk
          systemd
          iproute2
          util-linux
        ]
      }
  '';
}

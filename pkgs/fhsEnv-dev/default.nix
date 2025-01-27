{ pkgs ? import <nixpkgs> {} }:

let
  fhsEnv = pkgs.buildFHSUserEnv {
    name = "fhsEnv-dev";
    targetPkgs = pkgs: with pkgs; [
      ### Base pkgs
      bash
      coreutils

      ### Other pkgs
      gcc
      gnumake
      patch
      git
      gnutar
      gzip
      bzip2
      xz
      rsync
      wget
      cpio
      perl
      python3
      ncurses
      which
      file
      findutils
      util-linux
      openssl
      bc
      unzip
      libtool
      pkg-config
      flex
      bison
      gawk
      gettext
      texinfo
      patchutils
      swig
      gperf
      libelf
      libmpc
      mpfr
      gmp
    ];
    runScript = "bash";
  };
in
pkgs.runCommand "fhsEnv-shell" {} ''
  mkdir -p $out/bin
  echo "#!/bin/sh" > $out/bin/fhsEnv-shell
  echo "exec ${fhsEnv}/bin/fhsEnv-dev" >> $out/bin/fhsEnv-shell
  chmod +x $out/bin/fhsEnv-shell
''

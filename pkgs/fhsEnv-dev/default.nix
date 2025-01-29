{ pkgs }:

let
  fhsEnv = pkgs.buildFHSEnv {
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
      ncurses5.dev
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
      
      ### Library and headers
      libxcrypt
    ];
    runScript = "bash";
  };
in
pkgs.runCommand "fhsEnv-shell" {} ''
  mkdir -p $out/bin
  ln -s ${fhsEnv}/bin/fhsEnv-dev $out/bin/fhsEnv-shell
''

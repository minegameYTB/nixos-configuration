{ pkgs }:

let
  fhsEnv = pkgs.buildFHSEnv {
    name = "fhsEnv";
    targetPkgs = pkgs: with pkgs; [
    
      ### Build Dependency
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
      which
      file
      findutils
      util-linux
      openssl
      bc
      unzip
      pkg-config
      flex
      bison
      gawk
      gettext
      texinfo
      patchutils
      swig
      gperf
      mpfr
      gmp
      
      ### Library and headers
      libxcrypt
      libtool
      libmpc
      libelf
      ncurses5.dev
    ];
    runScript = "bash";
  };
in
pkgs.runCommand "fhsEnv-shell" {} ''
  mkdir -p $out/bin
  ln -s ${fhsEnv}/bin/fhsEnv $out/bin/fhsEnv-shell
''

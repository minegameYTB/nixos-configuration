{ stdenvNoCC, buildFHSEnv, lib, gcc }:

let
  fhsEnv = buildFHSEnv {
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
stdenvNoCC.mkDerivation rec {
  pname = "fhsEnv-shell";
  version = gcc.version;

  ### stdenv options
  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;
  dontPatchElf = true;

  installPhase = ''
  ### Make fhsEnv-shell available
    mkdir -p $out/bin
    ln -s ${fhsEnv}/bin/fhsEnv $out/bin/fhsEnv-shell
  '';

  meta = with lib; {
    description = "A build-essential like tool, but multi-distribution";
    license = licenses.gpl3;
  };
}

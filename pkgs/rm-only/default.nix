{ stdenvNoCC, coreutils }:

let
  ### Assigniate variable to rmBin
  rmBin = "${coreutils}/bin/rm";
in

stdenvNoCC.mkDerivation {
  pname = "rm-only";
  version = coreutils.version;
  
  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;
  dontPatchElf = true;

  installPhase = ''
    mkdir -p $out/bin
    cp ${rmBin} $out/bin/rm
  '';

  ### Use only coreutils from local nix-store (defined on the header)
  nativeBuildInputs = [ coreutils ];

  ### Disable metadata
 #meta = {
 #  description = "Standalone 'rm' binary extracted from coreutils";
 #  license = pkgs.lib.licenses.gpl3Plus;
 #  platforms = pkgs.lib.platforms.all;
 #};
}

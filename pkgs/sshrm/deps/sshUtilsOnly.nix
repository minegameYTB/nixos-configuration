{ stdenvNoCC, openssh }:

let
  ### Use only ssh explicit binary on this app
  sshOnly = "${openssh}/bin/ssh";
  sshKeygenOnly = "${openssh}/bin/ssh-keygen";
in

stdenvNoCC.mkDerivation {
  pname = "ssh-only";
  version = openssh.version;

  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;
  dontPatchElf = true;

  ### Only link ssh utils used by the derivation
  nativeBuildInputs = [ openssh ];

  installPhase = ''
    mkdir -p $out/bin
    ln -s ${sshOnly} $out/bin/ssh
    ln -s ${sshKeygenOnly} $out/bin/ssh-keygen
  '';
}

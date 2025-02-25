{ lib, stdenvNoCC, openssh, makeWrapper, fetchFromGitHub, callPackage }:

let
  ### Import sshUtilsOnly derivation
  sshUtilsOnly = callPackage ./deps/sshUtilsOnly.nix {};
in

 stdenvNoCC.mkDerivation rec {
   repoName = "sshrm";
   pname = "sshrm";
   version = "git-${builtins.substring 0 7 src.rev}"; ### Update dynamically the version number (based on git commit version)

  src = fetchFromGitHub {
    owner = "aaaaadrien";
    repo = repoName;
    rev = "0803f982130ebcceb43abe4fe84da3541856ed46";
    sha256 = "sha256-Sm9RAK6UdvL0yHfE12gIjoLfy3pZBqgRtfm20X1FWm0=";
  };

  outputs = [ "out" "doc" ];
  outputsToInstall = outputs;
  buildInputs = [ sshUtilsOnly makeWrapper ];

  installPhase = ''
    ### Make sshrm available
    mkdir -p $out/bin $doc/share/doc/${pname}
    cp ${pname} $out/bin/${pname}

    ### Add license file accessible on the doc directory
    cp LICENSE $doc/share/doc/${pname}/LICENSE
    cp README.md $doc/share/doc/${pname}/README.md
  '';
  
  postFixup = ''
    ### Add runtime path to sshrm tool
    wrapProgram $out/bin/${pname} \
      --set PATH ${lib.makeBinPath [ sshUtilsOnly ]} \
      --set TERM xterm-256color
  '';
 }

### An example with sshrm package

{ lib, stdenvNoCC, openssh, makeWrapper, fetchFromGitHub, callPackage }:

let
  ### Import sshUtilsOnly derivation
  sshUtilsOnly = callPackage ./deps/sshUtilsOnly.nix {};
  
  /* 
     - This instruction import the dependency "sshUtilsOnly" on this package
     - here some example with callPackage : packageName = callPackage ./<directory> {}
       (Add option of this expression here or or leave this field empty (no particular flag defined))
     
     - in the "let ... in" instruction, you can create variable to use it in the expression
     in this case, we create "sshUtilsOnly" variable, it use the callPackage instruction to evaluate "./deps/sshUtilsOnly"
     (available in ../pkgs/sshrm directory) as a derivation/package
  */
in

 ### In this example, i use "stdenvNoCC" because i dont need C compiler for this derivation, if you need the compiler, use stdenv (to use gcc compiler) or "clangStdenv" to use clang instead of gcc
 stdenvNoCC.mkDerivation rec {
   ### the option "rec" in stdenv we allows to use variable (use in stdenv) to other field (?) in this function
   repoName = "sshrm";
   pname = "sshrm";
   version = "git-${builtins.substring 0 7 src.rev}"; ### Update dynamically the version number (based on git commit version)

  src = fetchFromGitHub { 
    /* 
       The field "src" can use other path than fetchFromGithub
       see "fetchers" in nixpkgs documentation (https://nixos.org/manual/nixpkgs/stable/#chap-pkgs-fetchers)
    */
    owner = "aaaaadrien";
    repo = repoName;  
    /* 
      As you can see, 
      i use the recursive variable called "repoName" 
      (used on top of "src" section) as a string variable which provide "sshrm" (repoName = "sshrm")
    */
    rev = "0803f982130ebcceb43abe4fe84da3541856ed46";
    ### the "sha256" is important for nix, set this field empty to got the sha256 when you testing your build
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

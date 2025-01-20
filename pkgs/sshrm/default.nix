{ lib, stdenvNoCC, openssh, makeWrapper, fetchFromGitHub }:

 stdenvNoCC.mkDerivation rec {
   repoName = "sshrm";
   pname = "sshrm";
   version = "git-0803f98";

  src = fetchFromGitHub {
    owner = "aaaaadrien";
    repo = repoName;
    rev = "0803f982130ebcceb43abe4fe84da3541856ed46";
    sha256 = "sha256-Sm9RAK6UdvL0yHfE12gIjoLfy3pZBqgRtfm20X1FWm0=";
  };

  buildInputs = [ openssh makeWrapper ];

  installPhase = ''
    ### Make sshrm available to nix
    mkdir -p $out/bin
    cp ${pname} $out/bin/${pname}
    chmod +x $out/bin/${pname}
    wrapProgram $out/bin/${pname} \
      --prefix PATH : ${lib.makeBinPath [openssh]}

    ### Add license file accessible on the right directory
    mkdir -p $out/share/doc/sshrm
    cp LICENSE $out/share/doc/sshrm/LICENSE
    cp README.md $out/share/doc/sshrm/README.md
  '';

  #meta = with stdenv.lib; {
  #  description = "A tool to remove quickly all keys belonging to the specified host from a known_hosts file.";
  #  homepage = "https://github.com/aaaaadrien/sshrm";
  #  license = licenses.gpl3;
  #  maintainers = with maintainers; [ minegameYTB ];
  #  platforms = lib.platforms.linux;
  #};
 }

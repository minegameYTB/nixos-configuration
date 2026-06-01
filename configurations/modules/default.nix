{
  lib,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ### Declare all modules (on all sections)
    ./programs
    ./misc
    ./virtualisation
    #./nix

    ### Add other section here with a default.nix to enumerate all modules
  ];
}

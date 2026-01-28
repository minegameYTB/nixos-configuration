{ ... }:

{
  ### Import all common expression
  imports = [
    ./config.nix
    ./cli-packages.nix
    ./custom-pkgs.nix
    #./neovim.nix
  ];
}

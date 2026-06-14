{ config, pkgs, ... }:

{
  ### Import all expr for the browser
  imports = [
    ./firefox
    #./zen-browser # Now enabled in HM (symlinked here)
  ];
}

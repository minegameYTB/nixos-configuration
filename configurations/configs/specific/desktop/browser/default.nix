{ config, pkgs, ... }:

{
  ### Import all expr for the browser
  imports = [
    ./firefox
  ];
}

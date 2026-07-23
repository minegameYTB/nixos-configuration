{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    (inputs.self + "/home-manager/config-modules/zen-browser")
  ];
}

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  containerCfg = import ./container-config.nix {
    inherit inputs pkgs;
    inherit (config.system) stateVersion;
  };
in
{
  boot.enableContainers = true;

  networking.nat = {
    enable = true;
    internalInterfaces = [ "ve-+" ];
    enableIPv6 = false;
  };

  containers.opencode = {
    autoStart = false;

    privateNetwork = true;
    hostAddress = "10.0.0.1";
    localAddress = "10.0.0.2";

    bindMounts = {
      "/home/minegame/workspace" = {
        hostPath = "/home/minegame/Projets";
        isReadOnly = false;
      };
      "/home/minegame/nixos-configuration" = {
        hostPath = "/home/minegame/nixos-configuration";
        isReadOnly = false;
      };
      "/home/minegame/.config/opencode" = {
        hostPath = "/home/minegame/.config/opencode";
        isReadOnly = false;
      };
    };

    config = containerCfg;
  };
}

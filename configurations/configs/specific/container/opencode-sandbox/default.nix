{
  config,
  pkgs,
  lib,
  inputs,
  users,
  ...
}:

let
  username = builtins.head users;

  containerCfg = import ./container-config.nix {
    inherit inputs pkgs username;
    inherit (config.system) stateVersion;
  };
in
{
  ### Create package to login directly into container
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "opencode-login" ''
      if [[ $(nixos-container status opencode) == "down" ]] then
        echo "Starting opencode container using sudo"
        sudo nixos-container start opencode
      fi
      echo "Login to the container opencode using ssh, please use your password defined in your container"
      exec -a "$0" ${config.programs.ssh.package}/bin/ssh $(nixos-container show-ip opencode)
    '')
  ];

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
      "/home/${username}/workspace" = {
        hostPath = "/home/${username}/Projets";
        isReadOnly = false;
      };
      "/home/${username}/nixos-configuration" = {
        hostPath = "/home/${username}/nixos-configuration";
        isReadOnly = false;
      };
      "/home/${username}/.config/opencode" = {
        hostPath = "/home/${username}/.config/opencode";
        isReadOnly = false;
      };
    };

    config = containerCfg;
  };
}

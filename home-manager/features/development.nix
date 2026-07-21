{ config, pkgs, inputs, ... }: {
  imports = [
    (inputs.self + "/home-manager/config-modules/lazyvim")
  ];
}

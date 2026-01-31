{ config, inputs, ... }:

{
  ### Import glfOS nvidia configuration (via inputs)
  imports = [ "${inputs.glfOS-modules}/modules/default/nvidia.nix" ];

  ### Enable this nvidia related option (pinning by GLF team)
  glf.nvidia_config.enable = true;
}

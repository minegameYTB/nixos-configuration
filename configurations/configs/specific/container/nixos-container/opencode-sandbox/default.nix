{
  users,
  ...
}:

let
  username = builtins.head users;
in
{
  nixosContainers.containers.opencode = {
    ### Container-internal NixOS config (see container-config.nix)
    configFile = ./container-config.nix;

    ### Host directories bound into the sandbox
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
  };
}

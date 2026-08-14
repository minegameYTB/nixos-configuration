### Example container — general-purpose model (template).
### Not registered in the aggregator (see ../default.nix), so it stays inert.
### To create a real container from it:
###   1. cp -r example <container-name>
###   2. rename "example" to <container-name> in this file
###   3. add "./<container-name>" to the imports of ../default.nix
{
  users,
  ...
}:

let
  ### First system user (minegame) — owner of the bind mount host dirs
  username = builtins.head users;
in
{
  nixosContainers.containers.example = {
    ### Container-internal NixOS config (see container-config.nix)
    configFile = ./container-config.nix;

    ### Start automatically at boot (default: false)
    # autoStart = true;

    ### IP addresses — null = automatic allocation 10.0.<idx>.1/.2
    ### (idx = position in the sorted list of enabled containers).
    ### Pin them for a stable IP across reorderings.
    # hostAddress = "10.0.5.1";
    # localAddress = "10.0.5.2";

    ### User used by the nixos-<name>-login script (default: first user)
    # sshUser = username;

    ### Disable the login script generation (default: true)
    # login = false;

    ### Host directories bound into the sandbox.
    ### Missing host dirs are auto-created and chowned by the
    ### nixos-container-bind-dirs service.
    bindMounts = {
      "/home/${username}/workspace" = {
        hostPath = "/home/${username}/Projets";
        isReadOnly = false; # read-write: work dir shared with the host
      };
      "/home/${username}/nixos-configuration" = {
        hostPath = "/home/${username}/nixos-configuration";
        isReadOnly = true; # read-only: read-only bind example
      };
    };
  };
}
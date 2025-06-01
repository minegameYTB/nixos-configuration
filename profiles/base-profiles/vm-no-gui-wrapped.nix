{ extraModules ? [], ... }@args:

{
 ### Import vm-no-gui-profile.nix to add extraModules from flake directly
 imports = [ ./vm-no-gui-profile.nix ] ++ extraModules;
}

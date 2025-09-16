{ ... }:

{
 ### Import all system-opts configuration
 imports = [
   ./boot-settings.nix
   ./environment.nix
   ./nix-settings.nix
   ./system-apps.nix
   ./system-settings.nix
   ./fonts.nix
   ./shell.nix
 ];
}

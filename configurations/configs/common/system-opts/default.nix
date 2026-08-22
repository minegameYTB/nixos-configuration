{ ... }:

{
  ### Import all system-opts configuration
  imports = [
    ./boot-settings.nix
    ./hardening.nix
    ./environment.nix
    ./nix-settings.nix
    ./system-apps.nix
    ./system-settings.nix
    ./disk-symlinks.nix
    ./fonts.nix
    ./shell.nix
    ./version.nix
  ];
}

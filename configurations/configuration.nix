# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    ### Core component (common to all configurations (desktop and server))
    ./configs/common/system-opts # System options
    ./configs/common/users.nix # User settings
    ./configs/common/system-pkgs.nix # System packages
    ./configs/common/timezone.nix # Timezone
    ./configs/common/security.nix # Security
    ./configs/overlays # Global package overlay
    ./modules # Modules implementation
  ];

  # Allow unfree packages
  #nixpkgs.config.allowUnfree = true;

  ### Enable Firejail (common config)
  #programs.firejail.enable = true;

  ###----------------------------------------------------------------

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?
}

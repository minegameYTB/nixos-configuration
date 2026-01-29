{ username, ... }:

{
  ### Use the username dynamic attribute (from flake.nix)
  home.username = username;
  home.homeDirectory = "/home/${username}";

  ### Import nix expression for desktop
  imports = [
    ../home-manager/home.nix # Common configuration
    ../home-manager/configs/customization
    ../home-manager/configs/desktop/gui-packages.nix # Related to GUI packages (need to use with a DE)
  ];
}

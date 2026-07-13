{
  username,
  extraModules ? [ ],
  ...
}:

{
  ### Use the username dynamic attribute (from flake.nix)
  home.username = username;
  home.homeDirectory = "/home/${username}";

  ### Import nix expression for hp-probook
  imports = [
    ../home-manager/home.nix # Common configuration
    ../home-manager/configs/common
    ../home-manager/configs/customization/cli-app.nix # Related to cli software configuration
  ];
}

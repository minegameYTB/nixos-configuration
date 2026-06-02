{
  config,
  pkgs,
  inputs,
  ...
}:

{
  ### Import nix-flatpak like an expression
  imports = [ inputs.declarative-flatpak.homeModules.default ];

  ### Declarative flatpak settings (do a script to install it automatically system side (with normal package manager))
  services.flatpak = {
    enable = true;
    remotes = {
      "flathub" = "https://flathub.org/repo/flathub.flatpakrepo";
    };
    packages = [
      ### Argument order (to see commit, do "flatpak info software")
      ### Search package with this command (for all used info)
      # {remote}:{type}/{ref}/[{arch}]/{branch}[:{commit}]
      "flathub:app/app.zen_browser.zen//stable"
    ];
  };
}

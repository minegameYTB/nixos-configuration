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
    # v4.2+ default: manage flatpaks on graphical-session.target (GUI apps
    # only). Set explicitly to silence the upstream builtins.trace nagging
    # on every evaluation.
    runWithoutGui = false;
    remotes = {
      "flathub" = "https://flathub.org/repo/flathub.flatpakrepo";
    };
    packages = [
      ### Argument order (to see commit, do "flatpak info software")
      ### Search package with this command (for all used info)
      # {remote}:{type}/{ref}/[{arch}]/{branch}[:{commit}]
      "flathub:app/it.mijorus.gearlever//stable"
    ];
  };
}

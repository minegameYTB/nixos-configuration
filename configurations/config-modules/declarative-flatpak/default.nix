{
  config,
  pkgs,
  inputs,
  ...
}:

{
  ### Import nix-flatpak like an expression
  imports = [ inputs.declarative-flatpak.nixosModules.default ];

  ### Declarative flatpak settings
  services.flatpak = {
    enable = true;
    remotes = {
      "flathub" = "https://flathub.org/repo/flathub.flatpakrepo";
    };
    packages = [
      ### Argument order (to see commit, do "flatpak info software")
      ### Search package with this command (for all used info)
      # {remote}:{type}/{ref}/[{arch}]/{branch}[:{commit}]

      #"flathub:app/io.github.shiftey.Desktop//stable"
      "flathub:app/io.mrarm.mcpelauncher//stable"
      "flathub:app/it.mq1.TinyWiiBackupManager//stable"
      #"com.usebottles.bottles"
    ];
  };

  ### Enable xdg portal
  xdg.portal.enable = true;
}

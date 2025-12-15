{
  lib,
  config,
  pkgsExtra,
  ...
}:

{
  ### Podman
  virtualisation.podman = {
    enable = true;
    package = pkgsExtra.pkgs-unstable.podman;
  };

  environment.systemPackages =
    (with pkgsExtra.pkgs-unstable; [ distrobox ])
    ++ (lib.optionals config.services.xserver.enable (with pkgsExtra.pkgs-unstable; [ distroshelf ]));
}

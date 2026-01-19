{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Podman
  virtualisation.podman = {
    enable = true;
    package = pkgs.pkgs-unstable.podman;
  };

  environment.systemPackages =
    (with pkgs.pkgs-unstable; [ distrobox ])
    ++ (lib.optionals config.services.xserver.enable (with pkgs.pkgs-unstable; [ distroshelf ]));
}

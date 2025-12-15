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
  };

  environment.systemPackages =
    (with pkgs; [ distrobox ])
    ++ (lib.optionals config.services.xserver.enable (with pkgs; [ distroshelf ]));
}

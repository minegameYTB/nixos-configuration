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
    package = pkgs.pkgsUnstable.podman;
  };

  environment.systemPackages =
    (with pkgs.pkgsUnstable; [ distrobox ])
    ++ (lib.optionals config.services.xserver.enable (with pkgs.pkgsUnstable; [ distroshelf ]));
}

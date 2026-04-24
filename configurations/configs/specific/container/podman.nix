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
    dockerCompat = true;
    dockerSocket.enable = true;
    package = pkgs.podman;
  };

  environment.systemPackages =
    (with pkgs.pkgsUnstable; [ distrobox ])
    ++ (lib.optionals config.services.xserver.enable (with pkgs.pkgsUnstable; [ distroshelf ]));
}

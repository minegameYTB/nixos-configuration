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
    package = pkgs.podman;
  };

  environment.systemPackages =
    (with pkgs.pkgsUnstable; if !config.services.xserver.enable then [ distrobox ] else [ ])
    ++ (lib.optionals config.services.xserver.enable (with pkgs.pkgsUnstable; [ distroshelf ]));
}

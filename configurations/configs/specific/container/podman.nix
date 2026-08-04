{
  lib,
  config,
  pkgs,
  ...
}:

{
  ### Per-subsystem switch, set at the machine profile level
  options.containerSubsystems.podman = lib.mkEnableOption "Podman subsystem";

  config = lib.mkIf config.containerSubsystems.podman {
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
  };
}

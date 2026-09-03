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

    ### Python http.server (ex: python3 -m http.server 8000) pour servir les sets NetBSD
    networking.firewall.allowedTCPPorts = [ 8000 ];
  };
}

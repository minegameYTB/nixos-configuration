{ config, pkgsExtra, ... }:

{
  ### Tailscale (server specific option)
  services.tailscale = {
    enable = true;
    package = pkgsExtra.pkgs-unstable.tailscale;
    useRoutingFeatures = "server";
    openFirewall = true;

    ### Add this node as a "exit node"
    extraSetFlags = [
      "--advertise-exit-node"
    ];

    ### Add "exit node" settings
    extraUpFlags = [
      "--exit-node-allow-lan-access"
    ];
  };
}

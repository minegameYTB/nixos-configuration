{ config, pkgs, ... }:

{
 ### Tailscale (server specific option)
 services.tailscale = {
   enable = true;
   useRoutingFeatures = "server";
 };
}

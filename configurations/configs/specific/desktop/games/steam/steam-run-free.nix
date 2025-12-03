{ config, pkgs, ... }:

{
  ### Add steam-run to run fhs required apps (not only gaming apps)
  environment.systemPackages = with pkgs; [ steam-run-free ];
}

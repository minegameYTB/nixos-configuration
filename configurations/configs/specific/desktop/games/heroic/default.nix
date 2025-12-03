{ config, pkgs, ... }:

{
  ### Add heroic games launcher
  environment.systemPackages = with pkgs; [ heroic ];
}

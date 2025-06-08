{ config, pkgs, ... }:

{
 ### Add prismlauncher to global profile
 environment.systemPackages = with pkgs; [ prismlauncher ];
}

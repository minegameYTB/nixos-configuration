{ config, pkgs, ... }:

{
 ### Add Azahar
 environment.systemPackages = with pkgs; [ azahar ];
}

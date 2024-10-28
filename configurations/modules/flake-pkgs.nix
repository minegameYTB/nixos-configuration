{ config, pkgs, ... }:

{
 ### Flake pkgs
 environment.systemPackages = with pkgs; [
    inputs.nixos-conf-editor.packages.${system}.nixos-conf-editor
 ];
  
}

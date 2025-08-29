{ config, pkgs, ... }:

{
 home.packages = with pkgs; [
        
   ### Utilities
   jq
   dhall-json
   ripgrep
   #screen
 ];

}

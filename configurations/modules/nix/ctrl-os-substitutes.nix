{
  lib, 
  config,
  pkgs,

  ### Flake specific
  inputs,
  ...
}:

let
  cfg = config.ctrl-os.substitutes;
in
{
 options.ctrl-os.substitutes = {
   enable = lib.mkOption {
     type = lib.types.bool;
     default = false;
     description = "Whether to enable substitutes server for ctrl-os lts server.";
   };
 };
 
 ### -- Implementation --
 config = lib.mkIf cfg.enable {
   nix = {
     ### Enable registry for nix flake cli
     registry = {
       ctrlos.to = {
         type = "path";
         path = inputs.ctrl-os;
       };
     };

     ### Enable substitute server
     settings = {
       substituters = [
         "https://cache.ctrl-os.com/"
       ];
       trusted-substituters = [
         "https://cache.ctrl-os.com/"
       ];
       trusted-public-keys = [
         "ctrl-os:baPzGxj33zp/P+GAIJXsr8ss9Law+qEEFViX1+flbv8="
       ];
     };
   };
 };
}

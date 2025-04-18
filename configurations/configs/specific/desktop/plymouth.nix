{ lib, config, pkgs, ... }:

{
  boot = {
   plymouth = {
     enable = true;
     theme = lib.mkDefault "bgrt";
   };
  };
}

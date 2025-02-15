{ lib, config, pkgs, ... }:

{
  boot = {
   plymouth = {
     enable = true;
     theme = "bgrt";
   };
  };
}

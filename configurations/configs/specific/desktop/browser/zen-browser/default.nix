{ 
  lib,
  config,
  pkgs,
  zen-browser,
  ...
}:

{
 ### Install zen-browser from custom modules (see /configurations/modules/programs/zen-browser-modules.nix for all options)
 programs.zen-browser = {
   enable = true;
   enableHardening = true;
 };
}

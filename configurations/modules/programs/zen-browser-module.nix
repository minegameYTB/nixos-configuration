{ lib, config, pkgs, zen-browser, ... }

let
  cfg = config.programs.zen-browser;
in
{
 ### Declare option
 option.programs.zen-browser = {
   enable = lib.mkOption {
     type = lib.types.bool;
     default = false;
     description = "Whether to enable the Zen web browser.";
   };
   packages = mkOption {
     type = lib.types.package;
     default = pkgs.zen-browser.packages."${pkgs.stdenvNoCC.hostPlatform.system}".default;
     description = "Zen browser package to use";
     defaultText = lib.literalExpression "pkgs.firefox";
   };
 };
 
 ### -- Implementation --
 config = lib.mkIf cfg.enable {
   ### Add zen browser to the global environment (obtain by config.zen-browser.package attr)
   environment.systemPackage = [ cfg.package ];
 };
}

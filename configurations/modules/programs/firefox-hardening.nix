{ lib, config, pkgs, zen-browser, ... }:

let
  cfg = config.programs.firefox;
in
{
 ### Declare option
 options.programs.firefox = {
   enableHardening = lib.mkOption {
     type = lib.types.bool;
     default = false;
     description = "Whether to enable hardening to the Firefox web browser.";
   };
 };
 
 ### -- Implementation --
 config = lib.mkIf cfg.enableHardening {
   ### Enable hardening to firefox
   programs.firejail.wrappedBinaries = {
     firefox = {
       ### Refer binary with lib.getExe (see https://nixos.org/manual/nixpkgs/stable/#function-library-lib.meta.getExe-prime)
       executable = "${lib.getExe config.programs.firefox.package}";
       profile = "${pkgs.firejail}/etc/firejail/firefox.profile";
       #extraArgs = [
       #  "--disable-mnt"
       #  "--private-tmp"
       #  "--private-dev"
       #  "--keep-dev-shm"
       #];
     };
   };
 };
}

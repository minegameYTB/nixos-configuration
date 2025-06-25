{ lib, config, pkgs, ... }:

{
 ### Firefox
 programs.firefox = {
   enable = true;
   wrapperConfig.pipewireSupport = true;
   languagePacks = [
     "fr"
     "en-US"
   ];
   preferences = {
     "intl.accept_languages" = "fr-fr,en-us,en";
     "intl.locale.requested" = "fr,en-US";
   };
 };

 ### Firejail configuration for firefox (enabled on ../default.nix)
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
}

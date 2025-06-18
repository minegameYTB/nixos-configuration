{ 
  lib,
  config,
  pkgs,
  zen-browser,
  
  ### Add "system" as a function here (for zen-browser (in firejail section))
  system,
  ...
}:

{
 ### Install zen-browser from inputs.zen-browser (specialArgs)
 environment.systemPackages = with pkgs; [
   zen-browser.packages."${system}".default
 ];

 ### Prevent infinite recursion (script make folder who make folder... ect)
 systemd.user.services.create-firejail-zen-dir = {
   enable = true;
   description = "Create Firejail private zen directory";
   serviceConfig = {
     PATH = "${pkgs.coreutils}/bin";
     Type = "oneshot";
     ExecStart = "${pkgs.coreutils}/bin/mkdir -p %h/private/zen";
   };
   wantedBy = [ "graphical.target" ];
 };

 ### Firejail configuration for zen browser (enabled on ../default.nix)
 programs.firejail.wrappedBinaries = {
   zen = {
     ### Refer bin output with lib.getBin (see https://nixos.org/manual/nixpkgs/stable/#function-library-lib.attrsets.getBin)
     executable = "${lib.getBin zen-browser.packages."${system}".default}/bin/zen";
     extraArgs = [
       "--disable-mnt"
       "--private-tmp"
       "--private=~/private/zen"
     ];
   };
   ### Add zen-beta (could be removed when zen quit beta)
   zen-beta = {
     executable = "${lib.getBin zen-browser.packages."${system}".default}/bin/zen-beta";
     extraArgs = config.programs.firejail.wrappedBinaries.zen.extraArgs;
   };
 };
}

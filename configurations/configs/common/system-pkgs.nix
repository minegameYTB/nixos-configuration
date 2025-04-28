{ inputs, config, pkgs, pkgsExtra, ... }:

      
 let
   ### Add external packages
  #fhsEnv-dev = pkgs.callPackage ../../../pkgs/fhsEnv-dev {};
   
   ### Wrapper script
  #nixos-rebuild = pkgs.writeShellScriptBin "nixos-rebuild" ''
  #  exec -a "$0" ${pkgs.nixos-rebuild}/bin/nixos-rebuild -L "$@"
  #'';
 in
{
 nixpkgs.overlays = [
  #(import ../overlays/coreutils-full.nix) ### Overlays for coreutils-full (just compile tools for users and not runtime deps for software)
  #(import ../overlays/appimage-run.nix) ### Overlays to add some tools on appimage-run rootfs
  #(import ../overlays/gnome-control-center.nix) ### remove libwacom support (don't work as espect...)
  #(import ../overlays/package-name.nix)
 ];

 # List packages installed in system profile. To search, run:
 # $ nix search wget
 environment.systemPackages = with pkgs; [
     ### CLI
     wget
     jq
     nix-search-cli
     efibootmgr
     ntfs3g
     git
     bat
     lsd
     ripgrep

     ### Wrapper script
     #nixos-rebuild
   ]
 ++
   (with pkgsExtra.pkgs-unstable; [
   ### Use this part to install package from nixpkgs-unstable
 #    ventoy
   ]);
}

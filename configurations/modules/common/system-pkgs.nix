{ inputs, config, pkgs, pkgsExtra, zen-browser, ... }:

      
 let
   ### Add external packages
  #fhsEnv-dev = pkgs.callPackage ../../../pkgs/fhsEnv-dev {};
   
   ### Wrapper script
   nixos-rebuild = pkgs.writeShellScriptBin "nixos-rebuild" ''
     exec -a "$0" ${pkgs.nixos-rebuild}/bin/nixos-rebuild -L "$@" && exec zsh
   '';
 in
{
 # Allow unfree packages
 nixpkgs.config.allowUnfree = true;

 nixpkgs.overlays = [
  #(import ../overlays/coreutils-full.nix) ### Overlays for coreutils-full (just compile tools for users and not runtime deps for software)
  #(import ../overlays/appimage-run.nix) ### Overlays to add some tools on appimage-run rootfs
  #(import ../overlays/gnome-control-center.nix) ### remove libwacom support (don't work as espect...)
  #(import ../overlays/package-name.nix)
 ];

 # List packages installed in system profile. To search, run:
 # $ nix search wget
 environment.systemPackages = 
   (with pkgs; [
     ### Zen-browser (import sources with "inputs" prefix)
    #inputs.zen-browser.packages."${system}".default
     zen-browser.packages."${system}".default

     ### CLI
     wget2
     jq
     nix-search-cli
     efibootmgr
     ntfs3g
     git
     bat
     lsd

     ### Utilities
     gparted
     gearlever   
     virt-viewer
     ripgrep

     ### Other
     ghostty
     mission-center
     gnome-tweaks

     ### Themes
     papirus-icon-theme
     ayu-theme-gtk

     ### Wrapper script
     nixos-rebuild
   ])
 ++
   (with pkgsExtra.pkgs-unstable; [
   ### Use this part to install package from nixpkgs-unstable
 #    ventoy
   ]);
}

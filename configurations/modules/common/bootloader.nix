{ config, pkgs, ... }:

{
 # Bootloader
 boot.loader = {
   grub = {
     enable = true;
     device = "nodev";
     efiSupport = true;
     configurationLimit = 20;
     ### Create a 'in-config' derivation to package on the fly the theme (based on bootloader conf of Plasmaa0 for the theme part (github.com/Plasmaa0/NixOS-config))
     theme = pkgs.stdenv.mkDerivation rec {
          pname = "distro-grub-themes";
          version = "3.1";
          src = pkgs.fetchFromGitHub {
            owner = "AdisonCavani";
            repo = pname;
            rev = "47f983185d0de4f2f38254df12bc791520666a6e"; ### rev/tag 3.1
            hash = "sha256-ZcoGbbOMDDwjLhsvs77C7G7vINQnprdfI37a9ccrmPs=";
          };
          installPhase = "cp -r customize/nixos $out";
     };
   };
   efi.efiSysMountPoint = "/boot/efi";
 };  
}

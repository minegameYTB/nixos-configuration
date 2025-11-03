{ config, pkgs, ... }:

{
 ### Nvd diff hook
 system.activationScripts.report-changes = ''
   PATH="${pkgs.nvd}/bin:${pkgs.coreutils}/bin:${pkgs.nix}/bin"
   echo -e "\n===================================="
   echo      "| Running nvd diff to show changes |"
   echo -e   "====================================\n"
   nvd diff /run/current-system $systemConfig
   echo ""
 '';

 ### Zram
 zramSwap.enable = true;

 ### Fstrim
 services.fstrim.enable = true;

 ### Fwupd
 services.fwupd.enable = true;

 ### Nix-ld
 programs.nix-ld.enable = true;

 ### GVFS
 services.gvfs.enable = true;

 ### Udev
 services.udev.packages = [ pkgs.gnome-settings-daemon ];

 ### binfmt registration
 boot.binfmt.registrations = {
   appimage = {
     wrapInterpreterInShell = false;
     interpreter = "${pkgs.appimage-run}/bin/appimage-run";
     recognitionType = "magic";
     offset = 0;
     mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
     magicOrExtension = ''\x7fELF....AI\x02'';
   };
 };
}

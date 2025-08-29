{ config, pkgs, ... }:

{
 ### Systemd package
 systemd.package = let
   systemd = pkgs.systemd.override {
     ### Define name of custom version
     pname = "systemdCustom";

     ### Define option to disable
     withAnalyze = false;
     withFirstboot = false;
     withVmspawn = false;
     withRemote = false;
     withSysupdate = false;
     withNetworkd = false;
     withRepart = false;
   };
   systemdCustom = systemd.overrideAttrs (oldAttrs: {
     ### Disable checks
     doInstallCheck = false;
   });
 in systemdCustom;

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

{ config, pkgs, ... }:

{
 ### Nvd diff hook
 system.activationScripts.report-changes = ''
   PATH="${pkgs.nvd}/bin:${pkgs.coreutils}/bin:${config.nix.package}/bin"
   echo -e "\n===================================="
   echo      "| Running nvd diff to show changes |"
   echo -e   "====================================\n"
   nvd diff /run/current-system $systemConfig
   echo ""
 '';

 ### Ssh cli package (replace openssl by libressl)
 programs.ssh.package = pkgs.openssh.override {
   openssl = pkgs.libressl;
 };

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

 ### Appimage support
 programs.appimage = {
   enable = true;
   binfmt = true;
 };

 ### Old binfmt registration (deprecated (remove this in 25.11 beta))
 #boot.binfmt.registrations = {
 #  appimage = {
 #    wrapInterpreterInShell = false;
 #    interpreter = "${pkgs.appimage-run}/bin/appimage-run";
 #    recognitionType = "magic";
 #    offset = 0;
 #    mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
 #    magicOrExtension = ''\x7fELF....AI\x02'';
 #  };
 #};
}

{ config, pkgs, ... }:

{
  ### Nvd diff hook
  system.activationScripts.report-changes = ''
    ### Use report-changes hook as a function to use PATH as locale variable (instead of set it globally)
    report-changes(){
      PATH="${pkgs.nvd}/bin:${pkgs.coreutils}/bin:${config.nix.package}/bin"
      echo -e "\n===================================="
      echo      "| Running nvd diff to show changes |"
      echo -e   "====================================\n"
      nvd diff /run/current-system $systemConfig
      echo ""
    }

    ### Execute hook
    report-changes
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

  ### Openntpd client
  services.openntpd = {
    enable = true;
    servers = [
      "time.cloudflare.com"
      "0.fr.pool.ntp.org"
      "1.fr.pool.ntp.org"
      "2.fr.pool.ntp.org"
      "3.fr.pool.ntp.org"
    ];
  };
  # To use tsc if it's real device
  boot.kernelParams =
    if (config.services.qemuGuest.enable) then
      [
        "clocksource=kvm-clock"
      ]
    else
      [
        "clocksource=tsc"
        "tsc=reliable"
        "intel_idle.max_cstate=1"
      ];

  ### Appimage support
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}

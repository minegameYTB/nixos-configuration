{
  lib,
  inputs,
  config,
  pkgs,
  #ghostty,
  ...
}:

{
  environment.systemPackages =
    (with pkgs; [
      ### CLI
      wget
      efibootmgr
      ntfs3g
      nvd

      ### Pass $TERM env variable to ssh via a shell wrapper (and export openssh path as a global path for ssh wrapper)
      (pkgs.writeShellScriptBin "ssh" ''
        export PATH='${lib.getBin config.programs.ssh.package}'
        export TERM='xterm-256color'
        exec -a "$0" ${config.programs.ssh.package}/bin/ssh "$@"
      '')
      #nixos-rebuild
    ])
    ++ (with pkgs.pkgsUnstable; [
      ### Extra packages always installed (from pkgs.pkgsUnstable)
      #ventoy
    ])
    ++ (
      lib.optionals config.services.xserver.enable (
        with pkgs;
        [
          ### GUI Packages (only if X11 is enabled)
          gparted
          gearlever
          onlyoffice-desktopeditors
          github-desktop
          rpi-imager

          ### Ghostty
          #ghostty.packages.${pkgs.stdenvNoCC.hostPlatform.system}.default
          ghostty
        ]
      )
      ++ (with pkgs.pkgsUnstable; [
        ### Extra GUI packages from pkgs.pkgsUnstable (only if X11 is enabled)
        #bottles
      ])
    );
}

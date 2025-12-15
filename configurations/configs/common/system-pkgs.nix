{
  lib,
  inputs,
  config,
  pkgs,
  pkgsExtra,
  #ghostty,
  ...
}:

{
  environment.systemPackages =
    (with pkgs; [
      ### CLI
      wget
      nix-search-cli
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
    ++ (with pkgsExtra.pkgs-unstable; [
      ### Extra packages always installed (from pkgsExtra)
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

          ### Ghostty
          #ghostty.packages.${pkgs.stdenvNoCC.hostPlatform.system}.default
          ghostty # Use ghostty from nixpkgs to unpin mesa version
        ]
      )
      ++ (with pkgsExtra.pkgs-unstable; [
        ### Extra GUI packages from pkgsExtra (only if X11 is enabled)
        #bottles
      ])
    );
}

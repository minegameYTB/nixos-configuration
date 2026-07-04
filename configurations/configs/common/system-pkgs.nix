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
      # CLI
      wget
      file
      efibootmgr
      ntfsprogs-plus
      nvd
      mdcat

      # Man pages
      man-pages

      # Provide xdg-open alias (open) as a command
      (pkgs.writeShellScriptBin "open" ''
        exec -a "$0" ${pkgs.xdg-utils}/bin/xdg-open "$@"
      '')

    ])
    ++ (with pkgs.pkgsUnstable; [
      # Extra packages always installed (from pkgs.pkgsUnstable)
      #ventoy
    ])
    ++ (
      lib.optionals config.services.xserver.enable (
        with pkgs;
        [
          # GUI Packages (only if X11 is enabled)
          gparted
          rpi-imager
          easyeffects

          ### Chromium based browser
          vivaldi
          vivaldi-ffmpeg-codecs

          # Ghostty
          #ghostty.packages.${pkgs.stdenvNoCC.hostPlatform.system}.default
          ghostty
        ]
        ### x86_64 only GUI packages
        ++ lib.optionals pkgs.stdenvNoCC.hostPlatform.isx86_64 [
          onlyoffice-desktopeditors
          upscayl
        ]
      )
      ++ (with pkgs.pkgsUnstable; [
        # Extra GUI packages from pkgs.pkgsUnstable (only if X11 is enabled)
        #bottles
      ])
    );
}

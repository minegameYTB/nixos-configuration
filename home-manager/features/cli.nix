{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    jq
    dhall-json
    ripgrep
    fastfetch
    bat
    lsd
    duf

    nur.repos.minegameYTB.sshrm
    nur.repos.minegameYTB.GLFfetch-glfos
    nur.repos.minegameYTB.kvm-archive
    (nur.repos.minegameYTB.dev.fhsEnv-shell-buildroot.override {
      extraPkgs = with pkgs; [
        systemd.dev
        erofs-utils
        cryptsetup
        cryptsetup.dev
      ];
    })
  ];
}

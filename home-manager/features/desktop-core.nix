{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts-cjk-sans
    adw-gtk3
  ] ++ (with pkgs2511; [
    catppuccin-cursors.mochaDark
  ]);

  fonts.fontconfig.enable = true;
}

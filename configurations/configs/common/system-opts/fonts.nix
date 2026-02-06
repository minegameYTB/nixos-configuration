{ config, pkgs, ... }:

{
  ### NerdFonts
  #fonts.packages = with pkgs; [
  #  (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  #];

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono

      ### Japanese font
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
    ];
    fontDir.enable = true;
  };
}

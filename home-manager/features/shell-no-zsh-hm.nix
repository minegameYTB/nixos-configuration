{ config, pkgs, ... }:

{
  home.file.".zshrc".text = "### prevent zsh to show question regarding this file.";
}

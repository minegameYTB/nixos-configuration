{ config, pkgs, ... }:

{
  ### Active shell
  users.defaultUserShell = pkgs.zsh;

  ### Configurations
  programs.zsh = {
    enable = true;
    enableBashCompletion = true;
    vteIntegration = true;
    syntaxHighlighting = {
      enable = true;
      highlighters = [
        "main"
      ];
      styles = {
        "comment" = "fg=red,bold";
        "unknown-token" = "fg=red";
      };
    };
    autosuggestions = {
      enable = true;
      strategy = [ "match_prev_cmd" ];
    };
    ohMyZsh = {
      enable = true;
      theme = "agnoster";
    };
  };
}

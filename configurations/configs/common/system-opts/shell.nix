{ config, pkgs, ... }:

{
  ### Active shell
  users.defaultUserShell = pkgs.zsh;

  ### Configurations
  programs.zsh = {
    enable = true;
    enableBashCompletion = true;
    vteIntegration = true;
    interactiveShellInit = ''
      VM_OPTS="$(echo '-smp 2 -m 4096 -spice port=3001,disable-ticketing=on -device virtio-vga -display gtk')"
    '';
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

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
      #VM_OPTS="$(echo '-smp 2 -m 4096 -spice port=3001,disable-ticketing=on -device virtio-vga -display gtk')"

      function nix_shell_indicator() {
        if [[ -n $IN_NIX_SHELL ]]; then
          RPROMPT="%{$fg_bold[cyan]%}❄️ $IN_NIX_SHELL%{$reset_color%}"
        elif [[ -n $name ]]; then
          RPROMPT="%{$fg_bold[cyan]%}❄️ $name%{$reset_color%}"
        else
          RPROMPT=""
        fi
      }
      precmd_functions+=(nix_shell_indicator)
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

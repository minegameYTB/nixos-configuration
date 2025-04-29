{ config, pkgs, ... }:

{
 ### Zsh
 programs.zsh = {
   enable = true;
   enableBashCompletion = true;
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
   interactiveShellInit = ''
    #export NIXOS_VERSION=$(nixos-version | sed -E 's/^([0-9]+\.[0-9]+)\..*/\1/')
     export NIXPKGS_ALLOW_UNFREE=1
     export VM_OPTS=$(echo "-smp 2 -m 4096 -spice port=3001,disable-ticketing=on -device virtio-vga -display gtk")
   '';
  };

 ### Tmux
 programs.tmux = {
   enable = true;
   terminal = "screen-256color";
   clock24 = true;
   plugins = with pkgs; [
     tmuxPlugins.nord
   ];
 };

 ### Nix index
 programs = {
   nix-index = {
     enable = true;
     enableZshIntegration = true;
   };
   command-not-found = {
     enable = false;
   };
 };

 ### Neovim
 programs.neovim = {
   enable = true;
   viAlias = true;
   withPython3 = false;
   withRuby = false;
   configure = {
     customRC = ''
       colorscheme tokyonight-night
     '';
     packages.myVimPackage = with pkgs.vimPlugins; {
       start = [
         tokyonight-nvim
       ];
     };
   };
 };
}

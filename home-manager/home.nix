{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "minegame";
  home.homeDirectory = "/home/minegame";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    ### Theme
    adw-gtk3
    ### non-free apps
    discord
    spotify
    ### Video
    vlc
    ### Office
    onlyoffice-bin
    ### Editor
    vscode-fhs
    ### Games 
    prismlauncher
    ### Utilities
    rpi-imager
    localsend
    gitg
    jnv
    gnome-extension-manager
    bottles
    ### Replace retroarchFull with custom override inplace
    (retroarch.override {
      cores = with libretro; [
        genesis-plus-gx
        snes9x
        beetle-psx-hw
        dolphin
      ];
    })
    ### On nixos 25.05, replace actual override by overrideAttrs for retroarch 
    #(retroarch.overrideAttrs (oldAttrs: {
    # cores = with libretro; [
    #   libretro.genesis-plus-gx
    #   libretro.snes9x
    #   libretro.beetle-psx-hw
    #   libretro.dolphin
    # ];
    #}))
    ### End of override of retroarch
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/minegame/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "code";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

 ### Configure git
 programs.git = {
   enable = true;
   userName  = "Minegame YTB";
   userEmail = "53137994+minegameYTB@users.noreply.github.com";
 };

 ### Fastfetch
 programs.fastfetch = {
   enable = true;
   settings = {
   	 logo = {
   	   padding = {
   	     top = 1;
   	   };
   	 };
     modules = [
       "separator"
       "datetime"
       "os"
       "locale"
       "shell"
       "host"
       "kernel"
       "uptime"
       "packages"
       "display"
       "de"
       "wm"
       "cpu"
       "gpu"
       "memory"
       "swap"
       "battery"
       "poweradapter"
       "separator"
       "colors"
       "separator"
     ];
   };
 };
  
 ### htop
 programs.htop = {
   enable = true;
   settings = {
     show_merged_command = true;
     show_cpu_frequency = true;
     show_cpu_temperature  = true;
     show_thread_names = true;
     highlight_base_name = true;
     screen_tabs = true;
   };
 };

 ### Fish
 programs.fish = {
   enable = true;
   interactiveShellInit = ''
      set fish_greeting
      export NIXPKGS_ALLOW_UNFREE=1
   ''; 
 };
}

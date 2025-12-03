{
  config,
  pkgs,
  inputs,
  ...
}:

{
  xdg.configFile = {
    ### Install ghostty conf from my dotfiles (see flake.nix for the uri)
    "ghostty/config".source = "${inputs.dotfiles-minegameYTB}/configs/ghostty/config";
  };

}

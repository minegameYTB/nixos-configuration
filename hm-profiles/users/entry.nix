{ username, globalFeatures, userConfigs, featPath }:

let
  cfg = userConfigs.${username};
in

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  imports = map (f: "${featPath}/${f}.nix") (globalFeatures ++ cfg.hmFeatures);
}

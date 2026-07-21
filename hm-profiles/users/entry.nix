{ username, globalFeatures, userConfigs, featPath, userOverrides ? { } }:

let
  cfg = userConfigs.${username};

  globalOvr = userOverrides.global or { };
  effectiveGlobal =
    builtins.filter (f: !(builtins.elem f (globalOvr.without or [ ])))
      (globalFeatures ++ (globalOvr.extra or [ ]));

  userOvr = userOverrides.${username} or { };
  effectiveFeatures =
    builtins.filter (f: !(builtins.elem f (userOvr.without or [ ])))
      (cfg.hmFeatures ++ (userOvr.extra or [ ]));
in

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  imports = map (f: "${featPath}/${f}.nix") (effectiveGlobal ++ effectiveFeatures);
}

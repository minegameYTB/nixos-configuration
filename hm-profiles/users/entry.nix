{
  username,
  globalFeatures,
  userConfigs,
  featPath,
  userOverrides ? { },
  inputs,
}:

let
  cfg = userConfigs.${username};

  globalOvr = userOverrides.global or { };
  effectiveGlobal = builtins.filter (f: !(builtins.elem f (globalOvr.without or [ ]))) (
    globalFeatures ++ (globalOvr.extra or [ ])
  );

  userOvr = userOverrides.${username} or { };
  effectiveFeatures = builtins.filter (f: !(builtins.elem f (userOvr.without or [ ]))) (
    cfg.hmFeatures ++ (userOvr.extra or [ ])
  );
in

{
  home.username = username;
  home.homeDirectory = "/home/${username}";

  imports = [
    (inputs.self + "/home-manager/config-modules")
  ]
  ++ map (f: "${featPath}/${f}.nix") (effectiveGlobal ++ effectiveFeatures);
}

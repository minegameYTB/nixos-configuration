{
  username,
  globalFeatures,
  userConfigs,
  featPath,
  userOverrides ? { },
  inputs,
  # False on systems without system stylix: its NixOS module is what injects
  # the HM stylix module, so without it the `stylix.*` HM options don't exist
  # and importing features that set them would fail eval with "option
  # `stylix' does not exist". Currently only "gnome" sets such options
  # (home-manager/features/gnome.nix).
  withStylix ? true,
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

  stylixGatedFeatures = [ "gnome" ];
  selectedFeatures =
    if withStylix then
      effectiveGlobal ++ effectiveFeatures
    else
      builtins.filter (f: !(builtins.elem f stylixGatedFeatures)) (effectiveGlobal ++ effectiveFeatures);
in

{
  home.username = username;
  home.homeDirectory = "/home/${username}";

  imports = [
    (inputs.self + "/home-manager/config-modules")
  ]
  ++ map (f: "${featPath}/${f}.nix") selectedFeatures;
}

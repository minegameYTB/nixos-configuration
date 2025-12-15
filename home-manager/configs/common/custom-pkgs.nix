{
  config,
  pkgs,
  #nurpkgs-repo-minegameYTB,
  ...
}:

{
  home.packages = (
    with pkgs;
    [
      ### With nur namespace (nixpkgs stable)
      nur.repos.minegameYTB.sshrm
      nur.repos.minegameYTB.editor.msedit
      nur.repos.minegameYTB.GLFfetch-glfos
    ]
  );
  #++
  #  (with nurpkgs-repo-minegameYTB.legacyPackages.${pkgs.stdenvNoCC.hostPlatform.system}; [
  ### Custom packages
  ### Add custom-pkgs from my repo (nurpkgs-repo) (nixpkgs unstable)
  #sshrm
  #editor.msedit-rs
  #]);
}

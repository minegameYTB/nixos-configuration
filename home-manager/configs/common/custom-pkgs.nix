{ 
  config, 
  pkgs, 
  #nurpkgs-repo-minegameYTB, 
  ... 
}:

 let
   ### Add external packages
  #sshrm = pkgs.callPackage ../../../pkgs/sshrm {};
  #fhsEnv-shell = pkgs.callPackage ../../../pkgs/fhsEnv-dev {};
 in
{
 home.packages = 
   (with pkgs; [
     ### With nur namespace (nixpkgs stable)
     nur.repos.minegameYTB.sshrm
     nur.repos.minegameYTB.editor.msedit
     nur.repos.minegameYTB.GLFfetch-glfos
 ]);
 #++
 #  (with nurpkgs-repo-minegameYTB.legacyPackages.${pkgs.stdenvNoCC.hostPlatform.system}; [
     ### Custom packages
     ### Add custom-pkgs from my repo (nurpkgs-repo) (nixpkgs unstable)
     #sshrm
     #editor.msedit-rs
 #]);
}

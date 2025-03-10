{ ... }:

{
 ### Import nix expression for hp-probook
 imports = 
   [ ../home-manager/home.nix                                  ### Common configuration
     ../home-manager/configs/common/custom-pkgs.nix             ### Related to custom pkgs
     ../home-manager/configs/customization/cli-app.nix          ### Related to cli software configuration
   ];
}

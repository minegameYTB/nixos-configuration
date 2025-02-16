{ ... }:

{
 ### Import nix expression for hp-probook
 imports = 
   [ ../home-manager/home.nix                                   ### Common configuration
     ../home-manager/modules/common/custom-pkgs.nix             ### Related to custom pkgs
     ../home-manager/modules/customization/cli-app.nix          ### Related to cli software configuration
   ];
}

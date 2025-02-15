{ ... }:

{
 ### Import nix expression for hp-probook
 imports = 
   [ ../home-manager/home.nix
     ../home-manager/modules/gui-packages.nix
   ];
}

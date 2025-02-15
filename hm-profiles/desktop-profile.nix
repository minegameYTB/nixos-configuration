{ ... }:

{
 ### Import nix expression for hp-probook
 imports = 
   [ ../home-manager/home.nix                                   ### Common configuration
    #../home-manager/modules/common/custom-pkgs-cli-desktop.nix ### Related to custom pkgs
     ../home-manager/modules/customization/theme.nix            ### Related to theme configuration
     ../home-manager/modules/desktop/gui-packages.nix           ### Related to GUI packages (need to use with a DE)
   ];
}

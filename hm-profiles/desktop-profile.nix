{ ... }:

{
 ### Import nix expression for desktop
 imports = 
   [ ../home-manager/home.nix                                   ### Common configuration
     ../home-manager/configs/customization/theme.nix            ### Related to theme configuration
     ../home-manager/configs/customization/apps.nix             ### Related to app config
     ../home-manager/configs/customization/cli-app.nix          ### Related to cli software configuration
     ../home-manager/configs/desktop/gui-packages.nix           ### Related to GUI packages (need to use with a DE)
   ];
}

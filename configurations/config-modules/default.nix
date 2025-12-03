{
  ### Import all modules (specify what module to use in ../../profiles/<machine name>.nix to select a specific conf module)
  imports = [
    ./stylix
    #./nix-flatpak
    ./nix-index-db
    ./declarative-flatpak
  ];
}

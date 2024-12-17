self: super: {
  gnome-control-center = super.gnome-control-center.overrideAttrs (oldAttrs: {
    buildInputs = with self; oldAttrs.buildInputs ++ [
      # Ajoutez ici les dépendances que vous voulez conserver ou ajouter
    ] ++ lib.remove libwacom oldAttrs.buildInputs;
  });
}

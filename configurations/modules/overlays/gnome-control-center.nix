self: super: {
  gnome-control-center = super.gnome-control-center.overrideAttrs (oldAttrs: {
    buildInputs = with self; oldAttrs.buildInputs ++ [ ] ++ lib.remove libwacom oldAttrs.buildInputs;
  });
}

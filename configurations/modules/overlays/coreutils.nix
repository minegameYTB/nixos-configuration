self: super: {
  coreutils-full = super.coreutils-full.overrideAttrs (oldAttrs: {
    configureFlags = oldAttrs.configureFlags or [] ++ [ "--disable-single-binary" ];
  });
}

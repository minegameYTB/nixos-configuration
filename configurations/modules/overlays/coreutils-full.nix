self: super: {
  coreutils-full = super.coreutils-full.overrideAttrs (oldAttrs: {
    singleBinary = "no";
  });
}


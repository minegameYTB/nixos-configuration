self: super: {
  coreutils = super.coreutils.override {
    singleBinary = "no";
  };
}


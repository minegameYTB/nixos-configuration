self: super: {
  coreutils-full = super.coreutils-full.override {
    singleBinary = "no";
  };
}


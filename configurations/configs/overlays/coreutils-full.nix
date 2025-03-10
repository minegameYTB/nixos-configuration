self: super: {
 #coreutils-full = super.coreutils-full.override {
 #  singleBinary = "no";
 #};
  
  coreutils-full = super.coreutils-full.overrideAttrs (oldAttrs: {
    configureFlags = [
      "--with-packager=https://nixos.org"
      "--disable-single-binary"
      "--with-openssl"
      "gl_cv_have_proc_uptime=yes"
    ];
    doCheck = false;
  });
}


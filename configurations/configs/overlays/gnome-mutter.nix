### "super:" allow to use original argument from original expression (here, lib or pkgs (super.package to super.callPackage))

self: super: {
  mutter = super.mutter.overrideAttrs (oldAttrs: rec {
    version = "48.5";
    src = super.fetchurl {
      url = "mirror://gnome/sources/mutter/${super.lib.versions.major version}/mutter-${version}.tar.xz";
      hash = "sha256-Au0KtBlPxTdUD57pKsv1r4IJlxpATfMZwct3YylK5Ys=";
    };
  });
}

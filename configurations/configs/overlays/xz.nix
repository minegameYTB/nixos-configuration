### Example overlay for low-level / bootstrap packages like xz
### Demonstrates how to safely override packages in the stdenv chain

self: super: {
  ### Downgrade 5.8.3 (nixpkgs 26.05) -> 5.8.1
  ### Use self.fetchurl (not super.fetchurl) to avoid minimal-bootstrap cycle
  xz = super.xz.overrideAttrs (oldAttrs: rec {
    version = "5.8.1";
    src = self.fetchurl {
      url = "https://github.com/tukaani-project/xz/releases/download/v${version}/xz-${version}.tar.xz";
      hash = "sha256-C1T3nfhZElBN4LFK7Hlx4/lkSRrxgS2DRHAFgHUTzZ4=";
    };
  });
}

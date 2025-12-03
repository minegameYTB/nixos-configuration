{ ... }:

{
  ### Import expression for hm-standalone
  imports = [
    ./standalone-opts.nix

    ### Add external module
    ./config-modules
  ];
}

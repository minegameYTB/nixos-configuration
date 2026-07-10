{ ... }@args:
{
  machine = import ./machine.nix args;
  iso     = import ./iso.nix args;
}

{ ... }@args:
{
  machine = import ./machine.nix args;
  iso     = import ../iso/common.nix args;
}

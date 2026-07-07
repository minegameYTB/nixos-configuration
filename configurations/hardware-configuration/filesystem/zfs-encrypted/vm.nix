{
  lib,
  config,
  pkgs,
  ...
}:

{
  imports = [ ./default.nix ];

  ### In a VM, there is no mmc hardware — the key device is virtio (/dev/vdb1).
  ### mmc_block is harmless but unnecessary; keep it for parity with physical machines.
}

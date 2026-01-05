{ config, ... }:

{
  ### /tmp on zram (with compression)
  boot.tmp.useZram = true;
}

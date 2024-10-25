{ config, pkgs, ... }:

{
 ### qemu-guest-agent
 services.qemuGuest.enable = true;

 ### spice-vd-agent
 services.spice-vdagentd.enable = true;
}

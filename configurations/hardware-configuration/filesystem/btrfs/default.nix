{ config, lib, pkgs, modulesPath, ... }:

{
 imports = [ 
   (modulesPath + "/installer/scan/not-detected.nix")
 ];

 ### Mount Point
 fileSystems."/" = { 
   #device = "/dev/disk/by-label/nixos-root";
   label = "nixos-root";
   fsType = "btrfs";
   options = [ "subvol=@" "compress=zstd:5" "noatime" ];
 };

 fileSystems."/home" = { 
   label = "nixos-root";
   fsType = "btrfs";
   options = [ "subvol=@home" "compress=zstd:5" "noatime" ];
 };

 fileSystems."/nix" = { 
   label = "nixos-root";
   fsType = "btrfs";
   options = [ "subvol=@nix" "compress=zstd:5" "noatime" ];
 };

 ### Network stack
 # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
 # (the default) this is the recommended approach. When using systemd-networkd it's
 # still possible to use this option, but it's recommended to use it in conjunction
 # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
 networking.useDHCP = lib.mkDefault true;
 # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
 # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

 nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
 hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

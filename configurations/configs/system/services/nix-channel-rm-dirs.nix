{ lib, config, pkgs, ... }:


let
  ### Only use rm binary (hardening ?? idk..)
  rm-only = pkgs.callPackage ../../../../pkgs/rm-only {};
in
{
 systemd.services.nix-channel-rm-dirs = {
   wantedBy = [ "multi-user.target" ];
   environment = lib.mkForce {
     PATH = "${rm-only}/bin";
    };
   serviceConfig = {
     Type = "oneshot";
     User = "root";
   };
   script = ''
     rm -rf /root/.nix-defexpr/channels /nix/var/nix/profiles/per-user/root/channels
   '';
 };
}

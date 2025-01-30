{ lib, config, pkgs, ... }:

{
 systemd.services.nix-channel-rm-dirs = {
   wantedBy = [ "multi-user.target" ];
   environment = lib.mkForce {
     PATH = "${pkgs.coreutils}/bin";
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

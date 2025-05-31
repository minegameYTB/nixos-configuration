{ config, pkgs, inputs, ... }:

{
 # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

 # Configure network proxy if necessary
 # networking.proxy.default = "http://user:password@proxy:port/";
 # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

 # Enable networking
 networking.networkmanager.enable = true;

 # List services that you want to enable:

 #Enable the OpenSSH daemon.
 # services.openssh.enable = true;

 # Open ports in the firewall.
 # networking.firewall.allowedTCPPorts = [ ... ];
 # networking.firewall.allowedUDPPorts = [ ... ];
 # Or disable the firewall altogether.
 # networking.firewall.enable = false;
 
 ### BlockList (https://github.com/StevenBlack/hosts)
 ### (https://gitlab.com/librephoenix/nixos-config/-/blob/0324f60ab14f8551b72ea6078562813befc72786/system/security/blocklist.nix)
 networking.extraHosts = let 
   blocklist = builtins.readFile "${inputs.blocklist}/alternates/gambling-porn/hosts";
 in
 ''

   ${blocklist}
 '';
}

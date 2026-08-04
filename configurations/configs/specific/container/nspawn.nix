{
  config,
  lib,
  ...
}:

let
  cfg = config.nspawnctl;
in

{
  ### Per-subsystem switch, set at the machine profile level
  options.containerSubsystems.nspawn = lib.mkEnableOption "nspawnctl subsystem (systemd-nspawn on ZFS)";

  config = {
    ### Machine config for nspawnctl — the program module (options, package,
    ### /etc/nspawnctl.conf, systemd-nspawn@ override) lives in
    ### configurations/modules/virtualisation/nspawnctl.nix.
    nspawnctl.enable = config.containerSubsystems.nspawn;

    ### Network plumbing for ad-hoc nspawn containers and VMs.
    ### Per-machine network config lives in /etc/systemd/nspawn/<machine>.nspawn:
    ###   [Network]
    ###   VirtualEthernet=yes
    ###   Bridge=<cfg.bridge>
    ### Then simply: machinectl start <machine>
    systemd.network = lib.mkIf cfg.enable {
      enable = true;

      ### Bridge receiving the host side of container veth pairs and VM TAPs
      netdevs."nspawnctl-bridge" = {
        netdevConfig = {
          Name = cfg.bridge;
          Kind = "bridge";
        };
      };

      ### Bridge: static IP + DHCP server (pool 10.0.5.10-.249)
      networks."nspawnctl-bridge" = {
        matchConfig.Name = cfg.bridge;
        linkConfig.RequiredForOnline = "no";
        networkConfig = {
          Address = "10.0.5.1/24";
          ### Configure even without carrier (empty bridge): the address and
          ### DHCP server must be up before any container attaches
          ConfigureWithoutCarrier = true;
          DHCPServer = true;
        };
        dhcpServerConfig = {
          PoolOffset = 10;
          PoolSize = 240;
          EmitDNS = true;
          DNS = "1.1.1.1";
        };
      };

      ### systemd-networkd-wait-online can never succeed here: it requires at
      ### least one networkd-managed interface to be "online", but the bridge
      ### has no carrier until a container attaches. NetworkManager handles
      ### network-online.target on this machine.
      wait-online.enable = false;
    };

    ### Outbound NAT (bridge → WAN) — merges with nixos-containers framework's nat module
    networking.nat = lib.mkIf cfg.enable {
      enable = true;
      internalInterfaces = [ cfg.bridge ];
      ### Expose a container service via port forwarding (Wi-Fi / laptop):
      ###   networking.nat = {
      ###     externalInterface = "wlan0";
      ###     forwardPorts = [ { sourcePort = 5432; destination = "10.0.5.10:5432"; } ];
      ###   };
      ### Host reaches the service via 127.0.0.1:5432, the LAN via <host-IP>:5432.
      forwardPorts = [ ];
    };

    ### Routing between the bridge and the WAN interface
    boot.kernel.sysctl = lib.mkIf cfg.enable {
      "net.ipv4.ip_forward" = true;
    };
  };

  ### Expose containers as real machines on the LAN (Ethernet / self-host server):
  ###   /etc/systemd/nspawn/<machine>.nspawn:
  ###     [Network]
  ###     MacVLAN=enp3s0
  ###   Then: machinectl start <machine>
  ### The container gets its own LAN IP from the router's DHCP and is reachable
  ### by every LAN client — handy for DBs and servers.
  ### Caveats: the host itself cannot reach macvlan containers, and Wi-Fi APs
  ### drop frames from unknown source MACs, so macvlan does not work over Wi-Fi
  ### (use the forwardPorts approach above on the laptop).
}

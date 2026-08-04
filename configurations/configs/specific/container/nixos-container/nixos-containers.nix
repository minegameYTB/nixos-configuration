{
  config,
  lib,
  pkgs,
  inputs,
  users,
  ...
}:

let
  cfg = config.nixosContainers;

  ### Containers enabled, sorted by name -> stable auto-IP allocation
  enabledNames = lib.sort (a: b: a < b) (
    builtins.attrNames (lib.filterAttrs (_: c: c.enable) cfg.containers)
  );

  ### Auto-allocated subnet: 10.0.<idx>.1 (host) / 10.0.<idx>.2 (container)
  autoHostAddress = idx: "10.0.${toString idx}.1";
  autoLocalAddress = idx: "10.0.${toString idx}.2";

  ### containers.<name> entry derived from nixosContainers.<name>
  mkContainer =
    idx: name: c:
    {
      autoStart = c.autoStart;
      privateNetwork = true;
      hostAddress = if c.hostAddress == null then autoHostAddress idx else c.hostAddress;
      localAddress = if c.localAddress == null then autoLocalAddress idx else c.localAddress;
      bindMounts = lib.mapAttrs (_: m: {
        hostPath = m.hostPath;
        isReadOnly = m.isReadOnly;
      }) c.bindMounts;
      ### Container-internal NixOS module, evaluated with the host's pkgs:
      ### the container's own pkgs would miss the overlay (pkgsUnstable)
      config = import c.configFile {
        inherit inputs pkgs;
        stateVersion = config.system.stateVersion;
        username = c.sshUser;
      };
    };

  ### nixos-<name>-login: start the container, then ssh into it
  mkLoginScript =
    name: c:
    pkgs.writeShellScriptBin "nixos-${name}-login" ''
      if [[ $(nixos-container status ${name}) == "down" ]]; then
        echo "Starting ${name} container using sudo"
        sudo nixos-container start ${name}
      fi
      echo "Login to the container ${name} using ssh, please use your password defined in your container"
      exec -a "$0" ${config.programs.ssh.package}/bin/ssh ${c.sshUser}@$(nixos-container show-ip ${name})
    '';
in
{
  ### Per-subsystem switch, set at the machine profile level
  ### (configurations/configs/specific/container is imported by profiles/<machine>-profile.nix)
  options.containerSubsystems.nixos = lib.mkEnableOption "NixOS containers subsystem (declarative containers.*)";

  options.nixosContainers = {
    nat.enableIPv6 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable IPv6 NAT for container traffic.";
    };

    containers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether the container is created.";
          };

          autoStart = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether the container is automatically started at boot-time.";
          };

          hostAddress = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              IPv4 address of the host-side interface. When null, it is
              auto-allocated (10.0.<idx>.1, idx = position of the container
              in the sorted list of enabled containers).
            '';
          };

          localAddress = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              IPv4 address of the container interface. When null, it is
              auto-allocated (10.0.<idx>.2).
            '';
          };

          bindMounts = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule {
              options = {
                hostPath = lib.mkOption {
                  type = lib.types.str;
                  description = "Location of the host path to be mounted.";
                };
                isReadOnly = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether the mounted path is accessed read-only.";
                };
              };
            });
            default = { };
            description = "Host directories bound into the container.";
          };

          configFile = lib.mkOption {
            type = lib.types.path;
            description = ''
              NixOS module evaluated inside the container, as a function of
              { inputs, stateVersion, pkgs, username }.
            '';
          };

          sshUser = lib.mkOption {
            type = lib.types.str;
            default = builtins.head users;
            description = "User used by the auto-generated nixos-<name>-login script.";
          };

          login = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Generate a nixos-<name>-login script for this container.";
          };
        };
      });
      default = { };
      description = "Declarative NixOS containers (see containers.<name> options for the runtime).";
    };
  };

  config = lib.mkIf config.containerSubsystems.nixos {
    boot.enableContainers = true;

    ### Outbound NAT (ve-+ -> WAN) for all containers
    networking.nat = {
      enable = true;
      internalInterfaces = [ "ve-+" ];
      enableIPv6 = cfg.nat.enableIPv6;
    };

    ### Real containers.<name> entries
    containers = lib.listToAttrs (
      lib.imap0 (idx: name: lib.nameValuePair name (mkContainer idx name cfg.containers.${name})) enabledNames
    );

    ### Auto-generated login scripts
    environment.systemPackages = lib.mapAttrsToList mkLoginScript (
      lib.filterAttrs (_: c: c.enable && c.login) cfg.containers
    );
  };
}

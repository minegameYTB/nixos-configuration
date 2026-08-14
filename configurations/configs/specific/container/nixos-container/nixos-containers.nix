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

  ### Primary user (owner of the bind mount host dirs)
  primaryUser = builtins.head users;
  primaryGroup = config.users.users.${primaryUser}.group;

  ### Containers enabled, sorted by name -> stable auto-IP allocation
  enabledNames = lib.sort (a: b: a < b) (
    builtins.attrNames (lib.filterAttrs (_: c: c.enable) cfg.containers)
  );

  ### Auto-allocated subnet: 10.0.<idx>.1 (host) / 10.0.<idx>.2 (container)
  autoHostAddress = idx: "10.0.${toString idx}.1";
  autoLocalAddress = idx: "10.0.${toString idx}.2";

  ### name -> position in enabledNames (stable auto-IP allocation)
  nameToIdx = lib.listToAttrs (lib.imap0 (i: n: lib.nameValuePair n i) enabledNames);

  ### containers.<name> entry derived from nixosContainers.<name>
  mkContainer = idx: name: c: {
    autoStart = c.autoStart;
    privateNetwork = true;
    hostAddress = if c.hostAddress == null then autoHostAddress idx else c.hostAddress;
    localAddress = if c.localAddress == null then autoLocalAddress idx else c.localAddress;
    bindMounts = lib.mapAttrs (_: m: {
      hostPath = m.hostPath;
      isReadOnly = m.isReadOnly;
    }) c.bindMounts;
    ### Make the host flake inputs available to the container-internal modules
    ### (the container's own specialArgs default to {}). Used e.g. by
    ### nix-settings.nix to point NIX_PATH / the registry at nixpkgs-main.
    specialArgs = {
      inherit inputs;
    };
    ### Container-internal NixOS module, evaluated with the host's pkgs:
    ### the container's own pkgs would miss the overlay (pkgsUnstable).
    ### configFile + every configModules entry are imported as container
    ### modules with the shared signature { inputs, stateVersion, pkgs, username }.
    config =
      let
        mkCfg = f:
          import f {
            inherit inputs pkgs;
            stateVersion = config.system.stateVersion;
            username = c.sshUser;
          };
      in
      {
        imports = [ (mkCfg c.configFile) ] ++ (map mkCfg c.configModules);
      };
  };

  ### nixos-<name>-login: start the container if it is not running, wait
  ### for sshd to come up, then ssh into it — every step with error handling.
  ### The address is baked at build time (explicit localAddress or the
  ### auto-allocated 10.0.<idx>.2): it is fully deterministic and avoids
  ### non-root `nixos-container` calls (they try to mkpath /var/lib/nixos-containers
  ### and fail with EACCES on a fresh system).
  mkLoginScript =
    name: c:
    let
      idx = nameToIdx.${name};
      address = if c.localAddress == null then autoLocalAddress idx else c.localAddress;
    in
    pkgs.writeShellScriptBin "nixos-${name}-login" ''
      set -euo pipefail

      ip="${address}"
      ssh_bin="${config.programs.ssh.package}/bin/ssh"

      ### Start the container if its systemd unit is not active
      ### (systemctl is-active is safe to call without privileges)
      if [[ "$(systemctl is-active "container@${name}" 2>/dev/null || true)" != "active" ]]; then
        echo "Starting container '${name}' using sudo"
        sudo nixos-container start "${name}" || {
          echo "ERROR: failed to start container '${name}'" >&2
          echo "       Check the logs: journalctl -u container@${name}" >&2
          echo "       Also check the bind mount host paths (auto-created by nixos-container-bind-dirs)" >&2
          exit 1
        }
      fi

      ### Wait until sshd inside the container is reachable (max 120s,
      ### each probe bounded by timeout 2 so a dropped packet cannot stall it)
      start_ts="$(date +%s)"
      until timeout 2 bash -c "exec 3<>/dev/tcp/''${ip}/22" 2>/dev/null; do
        if (( $(date +%s) - start_ts >= 120 )); then
          echo "ERROR: container '${name}' not reachable at ''${ip}:22 after 120s" >&2
          echo "       Check: systemctl status container@${name}" >&2
          echo "              journalctl -u container@${name}" >&2
          exit 1
        fi
        sleep 1
      done

      echo "Login to the container '${name}' using ssh, please use your password defined in your container"
      exec -a "$0" "''${ssh_bin}" "${c.sshUser}@''${ip}"
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
      type = lib.types.attrsOf (
        lib.types.submodule {
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
              type = lib.types.attrsOf (
                lib.types.submodule {
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
                }
              );
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

            configModules = lib.mkOption {
              type = lib.types.listOf lib.types.path;
              default = [ ];
              description = ''
                Additional container-internal NixOS modules (paths to .nix
                files of this repo), imported with the same signature as
                configFile: { inputs, stateVersion, pkgs, username }.
                Use this to attach shared configuration modules to the
                container from its declaration, without touching
                container-config.nix.
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
        }
      );
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

    ### Create the host dirs of every bind mount and restore their ownership.
    ### systemd-nspawn --bind fails if the host path does not exist
    ### (fresh VM/install: /home/<user>/Projets is typically absent).
    ### tmpfiles `d` is NOT suitable here (it chowns and chmods existing
    ### dirs); however mkdir -p must be followed by chown-ing every newly
    ### created component: otherwise /home/<user>/.config ends up owned by
    ### root and the home-manager activation (running as the user) fails on
    ### ~/.config/dconf. Chowning the whole chain unconditionally also
    ### heals pre-existing root-owned parents.
    ### Derived from the declared bindMounts — nothing hardcoded.
    systemd.services.nixos-container-bind-dirs = {
      description = "Create missing bind mount host dirs for NixOS containers";
      wantedBy = [ "multi-user.target" ];
      before = [ "container@.service" ];
      serviceConfig.Type = "oneshot";
      script = lib.concatStringsSep "\n" (
        lib.flatten (
          lib.mapAttrsToList (
            _: c:
            lib.mapAttrsToList (_: m: ''
              base=/home/${primaryUser}
              mkdir -p "${m.hostPath}"
              d="${m.hostPath}"
              while [[ "$d" != "$base" ]]; do
                chown ${primaryUser}:${primaryGroup} "$d"
                d="''${d%/*}"
              done
            '') c.bindMounts
          ) (lib.filterAttrs (_: c: c.enable) cfg.containers)
        )
      );
    };

    ### Real containers.<name> entries
    ### (model/general-purpose template: see ./example in this directory;
    ### worked example: ./opencode-sandbox)
    containers = lib.listToAttrs (
      lib.imap0 (
        idx: name: lib.nameValuePair name (mkContainer idx name cfg.containers.${name})
      ) enabledNames
    );

    ### Auto-generated login scripts
    environment.systemPackages = lib.mapAttrsToList mkLoginScript (
      lib.filterAttrs (_: c: c.enable && c.login) cfg.containers
    );
  };
}

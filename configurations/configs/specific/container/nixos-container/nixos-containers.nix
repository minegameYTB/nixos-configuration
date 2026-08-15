{
  config,
  lib,
  pkgs,
  self,
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
  mkContainer = idx: c: {
    autoStart = c.autoStart;
    privateNetwork = true;
    hostAddress = if c.hostAddress == null then autoHostAddress idx else c.hostAddress;
    localAddress = if c.localAddress == null then autoLocalAddress idx else c.localAddress;
    bindMounts = lib.mapAttrs (_: m: {
      hostPath = m.hostPath;
      isReadOnly = m.isReadOnly;
    }) c.bindMounts;
    ### Make the host flake's self + inputs available to the container-internal
    ### modules (the container's own specialArgs default to {}). Used e.g. by
    ### nix-settings.nix to point NIX_PATH / the registry at nixpkgs-main.
    specialArgs = {
      inherit self inputs;
    };
    ### Container-internal NixOS module, evaluated with the host's pkgs:
    ### the container's own pkgs would miss the overlay (pkgsUnstable).
    ### configFile + every configModules entry are imported as container
    ### modules. configFile and path entries share the signature
    ### { self, inputs, stateVersion, pkgs, username }.
    config =
      let
        mkCfg = f:
          import f {
            inherit self inputs pkgs;
            stateVersion = config.system.stateVersion;
            username = c.sshUser;
          };
        ### Normalize a configModules entry: a path (or path string) is
        ### imported as a function of the shared signature; any other module
        ### value (flake module like inputs.home-manager.nixosModules.home-manager
        ### or inputs.self.nixosModules.<name>, attrset, function) is used as-is.
        mkModule = m: if lib.types.path.check m then mkCfg m else m;
      in
      {
        imports = [ (mkCfg c.configFile) ] ++ (map mkModule c.configModules);
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
                { self, inputs, stateVersion, pkgs, username }.
              '';
            };

            configModules = lib.mkOption {
              type = lib.types.listOf lib.types.unspecified;
              default = [ ];
              description = ''
                Additional container-internal NixOS modules. Each entry is
                either a path to a .nix file of this repo (imported as a
                function of { self, inputs, stateVersion, pkgs, username },
                same signature as configFile) or a module value used as-is —
                e.g. a flake module such as inputs.home-manager.nixosModules.home-manager
                or self.nixosModules.<name>, an attrset or a function.
                Attach shared or external config to the container from its
                declaration without touching container-config.nix.
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
        idx: name: lib.nameValuePair name (mkContainer idx cfg.containers.${name})
      ) enabledNames
    );

    ### Auto-generated login scripts
    environment.systemPackages = lib.mapAttrsToList mkLoginScript (
      lib.filterAttrs (_: c: c.enable && c.login) cfg.containers
    );

    ### Override the nixos-container CLI (same name) to add the
    ### list/status/start/stop/restart/login subcommands. Same pattern as the
    ### nixos-rebuild wrapper in nix-settings.nix: overrideAttrs + makeWrapper
    ### around a personal-command script; the real binary is renamed to
    ### .nixos-container-wrapped and reachable via NIX_REAL_CONTAINER (other
    ### native commands pass through to it). The wrapper is baked with the
    ### declared containers (registry below), so it works even when a container
    ### is not running.
    nixpkgs.overlays = [
      (self: super:
        let
          ### Declared containers, sorted by name, with their resolved runtime
          ### info (only consumed by the wrapper script below)
          containerInfo = lib.imap0 (idx: name: {
            inherit name;
            address =
              if cfg.containers.${name}.localAddress == null
              then autoLocalAddress idx
              else cfg.containers.${name}.localAddress;
            sshUser = cfg.containers.${name}.sshUser;
            login = cfg.containers.${name}.enable && cfg.containers.${name}.login;
          }) enabledNames;

          ### nixos-container wrapper script — manage all declared NixOS
          ### containers. The registry (names, addresses, ssh users) is baked
          ### in at build time from containerInfo. `login` delegates to the
          ### per-container nixos-<name>-login script.
          containersWrapperScript = ''
            set -euo pipefail

            ### Container registry baked at build time
            CONTAINERS=( ${lib.concatStringsSep " " (map (c: c.name) containerInfo)} )
            declare -A ADDRESS=( ${lib.concatStringsSep " " (map (c: "[${c.name}]=${c.address}") containerInfo)} )
            declare -A SSH_USER=( ${lib.concatStringsSep " " (map (c: "[${c.name}]=${c.sshUser}") containerInfo)} )
            declare -A LOGIN=( ${lib.concatStringsSep " " (map (c: "[${c.name}]=${if c.login then "1" else "0"}") containerInfo)} )

            usage() {
              cat <<'EOF'
            Usage: nixos-container <command> [name]

            Commands:
              list                    list all declared containers (name, IP, ssh user, status)
              status [name]           detailed status of all (or one) containers
              start <name>            start a container
              stop <name>             stop a container
              restart <name>          stop then start a container
              login <name>            ssh into a container (starts it first if needed)

            Any other command (create, destroy, update, ...) is passed through
            to the real nixos-container binary.
            EOF
            }

            ### Resolve <name> against the declared containers; error out otherwise
            resolve() {
              local name="''${1:-}"
              if [[ -z "''${ADDRESS[$name]+x}" ]]; then
                echo "Unknown container: $name" >&2
                echo "Declared containers: "''${CONTAINERS[*]}" " >&2
                exit 1
              fi
              printf '%s' "$name"
            }

            ### Privilege-free state probing via systemd
            container_state() {
              local s
              s="$(systemctl is-active "container@$1" 2>/dev/null || true)"
              case "$s" in
                active) printf 'active' ;;
                activating) printf 'activating' ;;
                inactive) printf 'stopped' ;;
                failed) printf 'failed' ;;
                *) printf 'unknown' ;;
              esac
            }

            cmd_list() {
              printf '%-15s %-13s %-10s %s\n' NAME IP 'SSH USER' STATUS
              local name
              for name in "''${CONTAINERS[@]}"; do
                printf '%-15s %-13s %-10s %s\n' "$name" "''${ADDRESS[$name]}" "''${SSH_USER[$name]}" "$(container_state "$name")"
              done
            }

            cmd_status() {
              local names
              if [[ $# -eq 0 ]]; then
                names=( "''${CONTAINERS[@]}" )
              else
                names=( "$(resolve "''${1:-}")" )
              fi
              local name state since
              for name in "''${names[@]}"; do
                state="$(container_state "$name")"
                since="$(systemctl show "container@$name" --property=ActiveEnterTimestamp --value 2>/dev/null || true)"
                printf '%-12s %s\n' 'Container:' "$name"
                printf '%-12s %s\n' 'Status:' "$state''${since:+ (up since $since)}"
                printf '%-12s %s\n' 'IP:' "''${ADDRESS[$name]}"
                printf '%-12s %s\n' 'SSH user:' "''${SSH_USER[$name]}"
                printf '%-12s %s\n' 'Login:' "$([[ "''${LOGIN[$name]}" == "1" ]] && echo yes || echo no)"
                echo
              done
            }

            cmd_start() {
              local name
              name="$(resolve "''${1:-}")"
              if [[ "$(container_state "$name")" == "active" ]]; then
                echo "Container '$name' is already running"
                return 0
              fi
              echo "Starting container '$name'"
              sudo "$NIX_REAL_CONTAINER" start "$name" || {
                echo "ERROR: failed to start container '$name'" >&2
                echo "       Check the logs: journalctl -u container@$name" >&2
                echo "       Also check the bind mount host paths (auto-created by nixos-container-bind-dirs)" >&2
                exit 1
              }
            }

            cmd_stop() {
              local name
              name="$(resolve "''${1:-}")"
              if [[ "$(container_state "$name")" == "stopped" ]]; then
                echo "Container '$name' is already stopped"
                return 0
              fi
              echo "Stopping container '$name'"
              sudo "$NIX_REAL_CONTAINER" stop "$name" || {
                echo "ERROR: failed to stop container '$name'" >&2
                exit 1
              }
            }

            cmd_restart() {
              cmd_stop "''${1:-}"
              cmd_start "''${1:-}"
            }

            cmd_login() {
              local name
              name="$(resolve "''${1:-}")"
              if [[ "''${LOGIN[$name]}" != "1" ]]; then
                echo "No login script generated for container '$name' (login = false)" >&2
                exit 1
              fi
              exec "nixos-''${name}-login"
            }

            main() {
              if [[ $# -lt 1 ]]; then
                usage >&2
                exit 1
              fi
              local cmd="$1"
              shift
              case "$cmd" in
                list) cmd_list "$@" ;;
                status) cmd_status "$@" ;;
                start) cmd_start "$@" ;;
                stop) cmd_stop "$@" ;;
                restart) cmd_restart "$@" ;;
                login) cmd_login "$@" ;;
                -h | --help | help) usage ;;
                *) exec "$NIX_REAL_CONTAINER" "$cmd" "$@" ;;
              esac
            }

            main "$@"
          '';
        in
        {
          nixos-container = super.nixos-container.overrideAttrs (
            oldAttrs: {
              nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ super.makeWrapper ];
              postInstall = (oldAttrs.postInstall or "") + ''
                mv $out/bin/nixos-container $out/bin/.nixos-container-wrapped
                makeWrapper ${super.writeShellScript "nixos-container-wrapper" containersWrapperScript} $out/bin/nixos-container \
                  --set NIX_REAL_CONTAINER "$out/bin/.nixos-container-wrapped"
              '';
            }
          );
        }
      )
    ];
  };
}

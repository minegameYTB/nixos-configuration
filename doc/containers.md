# Containers

This document covers the container stack of this configuration: the three subsystems (NixOS containers, Podman, nspawnctl), how to enable them per machine, and how to add new containers or new subsystem types.

## Overview

All container subsystems live in `configurations/configs/specific/container/` and are activated per machine via **gates** (`containerSubsystems.<type>`, default **off**):

| Gate | File | Provides |
|---|---|---|
| `containerSubsystems.nixos` | `nixos-container/nixos-containers.nix` | Declarative NixOS containers (`containers.*`): NAT, auto-IP, `nixos-<name>-login` scripts |
| `containerSubsystems.podman` | `podman.nix` | Podman (docker-compat, docker socket), distrobox, distroshelf |
| `containerSubsystems.nspawn` | `nspawn.nix` | nspawnctl: ad-hoc systemd-nspawn machines on ZFS (bridge + DHCP) |

All NixOS-container related files (framework, shared base, and every container declaration) live in the `nixos-container/` subfolder; new subsystem types (Docker, LXC, ...) are added as files at the `container/` level:

```
container/
├── default.nix           # Aggregator: imports every subsystem
├── podman.nix            # Podman subsystem (gate: containerSubsystems.podman)
├── nspawn.nix            # nspawnctl subsystem (gate: containerSubsystems.nspawn)
└── nixos-container/
    ├── default.nix       # Aggregator of the NixOS containers subsystem
    ├── nixos-containers.nix  # Framework (gate: containerSubsystems.nixos)
    ├── base.nix          # Shared container-internal base (containerBase)
    └── <name>/           # One directory per NixOS container
        ├── default.nix           # Declaration (bind mounts, configFile, ...)
        └── container-config.nix  # Container-internal NixOS module
```

Rules:

- Each subsystem file **declares its own gate** and stays fully inert when the gate is off — the folder can be imported by any machine without side effects.
- The gates are set at the **machine profile level** (`profiles/<machine>-profile.nix`).
- Importing the folder (`configurations/configs/specific/container`) is optional: a profile can also import only the subsystem file(s) it wants (`container/podman.nix`, ...).

### Machine profile example

```nix
# profiles/<machine>-profile.nix
{ ... }:
{
  imports = [ ../configurations/configs/specific/container ];

  ### Keep only what this machine needs
  containerSubsystems = {
    nixos = true;   # Declarative NixOS containers
    podman = false;
    nspawn = false;
  };
}
```

## The NixOS containers subsystem (`nixos-container/`)

### Host plumbing (automatic)

Enabling `containerSubsystems.nixos` automatically sets up:

- `boot.enableContainers = true`
- Outbound NAT for all containers (`networking.nat.internalInterfaces = [ "ve-+" ]`, `enableIPv6 = false` by default — override via `nixosContainers.nat.enableIPv6`)
- A `containers.<name>` entry per declared container (private veth network)
- Host directories of the declared `bindMounts` are auto-created at boot if missing (oneshot `nixos-container-bind-dirs` service — existing directories are never touched)
- A `nixos-<name>-login` script per container (starts the container if down, waits for sshd, then SSH into it — with error handling at every step)

### Declaring a container

Containers are declared under `nixosContainers.containers.<name>`:

```nix
# configurations/configs/specific/container/nixos-container/<name>/default.nix
{
  users,
  ...
}:
let
  username = builtins.head users;
in
{
  nixosContainers.containers.opencode = {
    configFile = ./container-config.nix;
    bindMounts = {
      "/home/${username}/workspace" = {
        hostPath = "/home/${username}/Projets";
        isReadOnly = false;
      };
    };
  };
}
```

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | bool | `true` | Create the container |
| `autoStart` | bool | `false` | Start at boot |
| `hostAddress` | nullOr str | `null` | Host-side IP. `null` → auto-allocated `10.0.<idx>.1` |
| `localAddress` | nullOr str | `null` | Container-side IP. `null` → auto-allocated `10.0.<idx>.2` |
| `bindMounts.<path>.*` | — | — | `hostPath` (required), `isReadOnly` (default `false`) |
| `configFile` | path | **required** | Container-internal module (see below) |
| `configModules` | list of unspecified | `[]` | Extra container-internal modules: a path to a `.nix` file of this repo (imported with the same signature as `configFile`) or any module value used as-is — flake module (`inputs.home-manager.nixosModules.home-manager`, `self.nixosModules.<name>`), attrset or function |
| `sshUser` | str | first system user | User of the generated `nixos-<name>-login` script |
| `login` | bool | `true` | Generate the `nixos-<name>-login` script |

**Auto-IP**: when `hostAddress`/`localAddress` are left `null`, the framework allocates `10.0.<idx>.1` (host) / `10.0.<idx>.2` (container), where `idx` is the position of the container in the **alphabetically sorted list of enabled containers**. Adding or removing containers shifts the indexes — pin explicit addresses if you need stability. The `opencode` container gets `10.0.0.1/10.0.0.2`.

**Attaching shared config modules**: to reuse config modules inside a container, list them in `configModules` from the declaration. Each entry is either a **path** to a `.nix` file (imported with the `{ self, inputs, stateVersion, pkgs, username }` signature — `pkgs` is the host's pkgs, so `pkgs.pkgsUnstable`/`pkgs.nur` are available) or a **module value used as-is** (flake modules, `self.*`, attrset or function):

```nix
{ inputs, ... }: {
  nixosContainers.containers.example = {
    configFile = ./container-config.nix;
    configModules = [
      ../../../../../../modules/my-service.nix        # path → shared signature
      inputs.home-manager.nixosModules.home-manager    # external flake module (inputs)
      (self + "/configurations/modules/foo.nix")       # internal module via self
      self.nixosModules.foo                            # internal module via self (if the flake exposes it)
    ];
  };
}
```

> `self` (the repo flake) and `inputs` (all flake inputs) are passed to every container-internal module — both as the path/signature arguments of `configFile`/`configModules` entries and through the container's `specialArgs` (so inline function modules and flake modules get them too).

### The container-internal module (`container-config.nix`)

The container is a separate NixOS system evaluated at build time. Its module is a function with a **fixed signature**:

```nix
# configurations/configs/specific/container/nixos-container/<name>/container-config.nix
{
  self,          # the repo flake (configurations/modules/..., self.nixosModules.<name>)
  inputs,        # flake inputs (from the host)
  stateVersion,  # host stateVersion (26.05)
  pkgs,          # HOST pkgs — the container's own pkgs has no overlay (pkgsUnstable would be missing)
  username,      # SSH user of the container (nixosContainers.containers.<name>.sshUser)
}:
{
  imports = [ (import ../base.nix { inherit stateVersion username; }) ];

  containerBase.git = {
    userName = "Minegame YTB";
    userEmail = "53137994+minegameYTB@users.noreply.github.com";
  };

  environment.systemPackages = with pkgs.pkgsUnstable; [
    opencode
    mcp-nixos
  ];
}
```

### Shared base (`nixos-container/base.nix`)

Import it with `imports = [ (import ../base.nix { inherit stateVersion username; }) ]` (relative to the container dir — the base lives in `nixos-container/base.nix`) to get: the user (`initialPassword = "nixos"`), hardened sshd, firewall (port 22), `nix-settings.nix`, git, and `system.stateVersion`. Tunable via `containerBase`:

> **NIX_PATH / flake registry**: `nix-settings.nix` points the container's `NIX_PATH` and `nix.registry.nixpkgs` at the host's pinned nixpkgs (`inputs.nixpkgs-main`, the real `/nix/store/<hash>-source` copy) instead of falling back to `nixos-unstable`. This only applies when nix is enabled in the container (`nix.enable`, default true). The host's `inputs` are made available to container-internal modules via `containers.<name>.specialArgs`.

| Option | Default | Description |
|---|---|---|
| `git.userName` / `git.userEmail` | `null` | Git identity (applied only when both are set) |
| `ssh.enable` | `true` | Hardened SSH server |
| `ssh.authorizedKeys` | `[]` | SSH public keys for the user |
| `ssh.passwordAuth` | `true` | Allow password authentication |
| `sudo` | `false` | Enable sudo (default: no root privileges) |
| `firewall.allowedTCPPorts` | `[ 22 ]` | Open TCP ports in the container |

## Adding a new NixOS container

1. **Create the container directory** and copy the templates:
   ```bash
   mkdir configurations/configs/specific/container/nixos-container/<name>
   cp example/nixos-container.nix.txt         configurations/configs/specific/container/nixos-container/<name>/default.nix
   cp example/nixos-container-config.nix.txt  configurations/configs/specific/container/nixos-container/<name>/container-config.nix
   ```
   A complete filled-in model is available in `configurations/configs/specific/container/nixos-container/example/` (`default.nix` + `container-config.nix` — not registered, copy it to a new name).
2. **Edit `default.nix`**: container name, bind mounts, optional `autoStart`/IPs/`sshUser`.
3. **Edit `container-config.nix`**: `containerBase` (git identity, SSH keys...) + the container-specific packages/services.
4. **Register the container** in `configurations/configs/specific/container/nixos-container/default.nix`:
   ```nix
   imports = [
     ./nixos-containers.nix
     ./opencode-sandbox
     ./<name>
   ];
   ```
5. **Enable the subsystem** on the machine (if not already): `containerSubsystems.nixos = true;` in `profiles/<machine>-profile.nix`.
6. **Rebuild and use**:
   ```bash
   sudo nixos-rebuild switch --flake .#<machine>
   nixos-container list               # see all declared containers + status
   nixos-container start <name>       # or: sudo systemctl start container@<name>
   nixos-<name>-login                 # auto-generated SSH login script
   ```

**Constraints**: container names must not contain underscores, and with `privateNetwork` on kernels < 5.8 names must be ≤ 11 characters.

### The `nixos-container` wrapper

The `nixos-container` CLI is overridden (same pattern as the `nixos-rebuild` wrapper: `overrideAttrs` + `makeWrapper`): the real binary is renamed to `.nixos-container-wrapped` and a wrapper at the same name adds convenience subcommands:

```bash
nixos-container list                 # compact table: all declared containers (name, IP, ssh user, status)
nixos-container status [<name>]      # detailed status of all (or one) container (state + uptime, IP, ssh user)
nixos-container start <name>         # start a container (no-op if already running)
nixos-container stop <name>          # stop a container (no-op if already stopped)
nixos-container restart <name>       # stop then start
nixos-container login <name>         # same as nixos-<name>-login (starts it first if needed)
```

- The wrapper is baked at build time with the declared containers (name, auto-allocated IP, ssh user) from the framework's `containerInfo` — so `list`/`status` work even for stopped containers.
- `start`/`stop`/`restart` delegate to the real binary via `sudo` (reachable through `NIX_REAL_CONTAINER`, set by `makeWrapper`).
- Any other native command (`create`, `destroy`, `update`, ...) passes through to the real binary.
- Status probing is privilege-free (`systemctl is-active container@<name>`).
- The login script (`nixos-<name>-login`, generated per container with `login = true`) stays available as-is.

## Adding a new container subsystem type (e.g. LXC, Docker, ...)

Each subsystem is a module file that (1) declares its own gate, (2) applies its config under that gate. A module that declares `options` must put **all** its configuration in an explicit `config` section (no other top-level attributes):

```nix
# configurations/configs/specific/container/docker.nix
{
  config,
  lib,
  pkgs,
  ...
}:
{
  ### Gate of the new subsystem (default: off, activated per machine profile)
  options.containerSubsystems.docker = lib.mkEnableOption "Docker subsystem";

  config = lib.mkIf config.containerSubsystems.docker {
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };
  };
}
```

Then:

1. Add `./docker.nix` to the `imports` of `configurations/configs/specific/container/default.nix`.
2. Enable it on the machine profile: `containerSubsystems.docker = true;` (or import `container/docker.nix` directly without the whole folder).

The gate options merge naturally across files: each file declares its own leaf of `containerSubsystems`, and profiles set all of them in one place.

## References

- Templates: `example/nixos-container.nix.txt`, `example/nixos-container-config.nix.txt`
- Complete model: `configurations/configs/specific/container/nixos-container/example/` (`default.nix` + `container-config.nix`)
- Framework implementation: `configurations/configs/specific/container/nixos-container/nixos-containers.nix`
- Worked example: `configurations/configs/specific/container/nixos-container/opencode-sandbox/`
- This repo's AGENTS.md also summarizes the container architecture for agents

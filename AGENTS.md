# NixOS Configuration — Agent Guide

Flake-based NixOS config on `nixpkgs-main` = **nixos-unstable** (current branch `prepare/nixos-26.11`).
15 `nixosConfigurations` in `machine.nix`: 13 machines (2 physical + 9 VM presets + 2 CI vanilla) + `iso-gnome` + `iso-minimal`.

## Flake wiring

- `flake.nix` — inputs, overlays, `specialArgs`, `mkMachine`/`mkHome`. Formatter is `nixfmt-tree` (`nix fmt`). Dev shell via `build.sh` → `nix develop --command make "$@"`; run make targets as `./build.sh <target>` outside NixOS.
- `machine.nix` — `mkMachine { hostname, profile, fs, extraModules ? [], arch ?, usePatched ? false, userOverrides ? {}, withHomeManager ? true }`. `lib/machine.nix` switches whole-system pkgs (`pkgsPatched` vs `pkgsFor`); `usePatched` is `false` everywhere (reserve mechanism).
- `lib/default.nix` re-exports `lib/machine.nix` (`mkMachine`) + `iso/common.nix` (`mkIso`/`mkIsoConfig`).
- `pkgs/default.nix` is the single source of truth for both the overlay's `pkgsConfig` and flake `packages`. Configs prefixed `iso-` are auto-exposed as flake packages, **x86_64-linux only**.
- `overlay.nix` — NUR + CachyOS kernel overlay (x86_64 only) + one `(self: super: ...)` overlay exposing `pkgsUnstable`, `pkgs2511`, `pkgsPr`, `pkgsConfig`. Convention: overlay lambdas in modules use `(self: super:)` — never `final:`/`prev:`.
- Two unreleased-package layers, do not conflate:
  - **Single package** — `nixpkgs-pr` input (`?ref=pull/537215/head`) → `pkgs.pkgsPr`, consumed in exactly one place: `configurations/configs/specific/ai/default.nix` (`claude-desktop`, xserver-gated).
  - **OS base** — `lib/nixpkgs-patches.nix` → `pkgsPatched` via `pkgs.fetchpatch` (currently PR 562812 libcap_ng static fix). Per-machine opt-in via `usePatched = true`.
- `lib/repo.nix` is the canonical `repoUrl` (packaging, `/etc/os-release` `CONFIG_URL`, install clone). Runtime override: `INSTALL_REPO_URL`. Branch comes from the `.branch` file.

## Machines: profile + marker + kernel

- `profiles/`: `hp-probook`, `hp-240` (physical) + `vm-desktop`/`vm-cli` + `ci` (vanilla, `ci-efi`/`ci-bios` for GHA) presets at `profiles/*-profile.nix` (`vm-*` + `ci-profile.nix`). `machine.nix` combines profile + fs module + bootloader per machine.
- `marker.hostProfile` (`desktop`|`server`) and `marker.archProfile` (`x86-64-v1..v4`, `amd-zen4`, `aarch64`) are **required** — missing values fail evaluation via assertions (`configurations/modules/misc/marker.nix`).
- Kernel (`configs/common/system-opts/cachyos-kernel.nix`): desktop → `linuxPackages-cachyos-bore-lto` (+ `-x86_64-v2/v3/v4` suffix); server → `linuxPackages-cachyos-server` (**v1 only**, other arch throws); aarch64 → stock `linuxPackages`. Pinned/custom kernels via flags in that file (default off = binary cache intact).

## Home Manager

- Single entry `hm-profiles/users/entry.nix`: `globalFeatures` + per-user `hmFeatures` → `home-manager/features/<name>.nix`. Users in `hm-profiles/users.nix` (currently only `minegame`); per-user overrides in `hm-profiles/users/<name>/`.
- `userOverrides` shape: `{ global = { without|extra }; <user> = { without|extra }; }` (see `cliOverrides` in `machine.nix`). ISO passes `hmFeatures` directly to `mkIso`.
- Two modes: NixOS-managed (`home-manager.nixosModule` + `homeManagerConfig`) and standalone (`mkHome`, `homeConfigurations.<user>@<system>`). See `doc/HM.md`.

## ISO (`iso/`, see `doc/ISO.md`)

- `common.nix`: `mkIsoConfig` + `mkIso`, welcome message, fixed machine-id (first 8 hex chars = ZFS hostId — keep it valid hex). `gnome.nix` (desktop) / `cli.nix` (minimal). Build: `nix build '.#iso-gnome'` / `'.#iso-minimal'` (or `make iso-gnome|iso-minimal|iso-all`).

## Containers (`configs/specific/container/`, see `doc/containers.md`)

- Per-subsystem gates `containerSubsystems.nixos|podman|nspawn` (default off, set in machine profile); only hp-probook enables them.
- `nixos-container/nixos-containers.nix`: `nixosContainers.containers.<name>` with host plumbing (NAT `ve-+`, auto-IP `10.0.<idx>.1/.2`, `nixos-<name>-login` scripts). Options: `enable`, `autoStart`, `hostAddress`/`localAddress` (null = auto), `bindMounts`, `configFile`, `configModules`, `sshUser`, `login`.
- `nixos-container` CLI is wrapped via `nixpkgs.overlays` (real binary → `.nixos-container-wrapped`, `NIX_REAL_CONTAINER` passthrough) adding `list|status|start|stop|restart|login`.
- Container-internal modules take `{ self, inputs, stateVersion, pkgs, username }` — `pkgs` must come from the host (container's own pkgs lack the overlay); shared base via `(import ../base.nix { inherit stateVersion username; })`.
- New container: create `nixos-container/<name>/{default.nix,container-config.nix}`, add `./<name>` to `nixos-container/default.nix`. Templates in `example/`.

## Install (`install-lib/`, `install.sh`, see `doc/INSTALL.md`)

- `install.sh` auto-detects NixOS vs standalone Linux (→ `nixos-install.sh` vs `hm-standalone-install.sh`).
- `nixos-install.sh` is checkpointed/resumable (`/tmp/nixos-install-state`); `step_copy_config` supports `.git/` copy, `.config-repo` pin, shallow clone, fallback.
- Disko: `configurations/disko-configuration/{current (4 active),unused (4)}`. No ZFS native encryption (`boot.zfs.requestEncryptionCredentials = false`); ZFS uses `devNodes = /dev/disk/by-fs/...` + `forceImportRoot = false` (see `doc/udev-by-fs.md`).

## Tests & checks

- Suites in `test/`: `bash test/<name>.sh` (install-logic, repo-info, update-flake-local, auto-update-sh, auto-update-checkout, nspawnctl, shell-paths).
- `make run-deadnix` (`deadnix -eqlL .`), `make run-shellcheck` (install.sh, build.sh, install-lib, test, script). Format with `nix fmt`.
- CI (`.github/workflows/flake-autoupdate.yml`): runs **all** `test/test-*.sh` + `nix eval` instantiate of `vm-cli-efi vm-desktop-efi vm-cli-efi-zfs`. Buffer branch `flake-autoupdate` soaks off `prepare/nixos-26.11` (`SOAK_RUNS=3`) — **never move the buffer pointer by hand**; see `doc/auto-update.md`.

## Gotchas

- `system.stateVersion = "24.05"` (do not bump casually); HM `home.stateVersion = "26.05"`.
- Bilingual FR/EN strings are intentional, not untranslated leftovers: the auto-update notification catalogue (`configurations/modules/misc/auto-update/errors.nix` `title_fr`/`body_fr`, success/notice texts in `auto-update/default.nix` main flow, `_notify_failure` fallback in `auto-update/notifier.nix`) ships both locales side by side with runtime `LANG` selection. When translating the repo to English, leave every French string in place.
- `networking.extraHosts` blocklist is **active but xserver-gated** (`lib.mkIf config.services.xserver.enable`): `extraHosts` is `types.lines`, an unguarded `lib.optionals` list breaks every headless build.
- No secrets in repo; initial passwords are `"nixos"`.
- Docs live in `doc/` (`INSTALL`, `ISO`, `containers`, `HM`, `modules`, `config-modules`, `auto-update`, `udev-by-fs`). Trust `flake.nix`/`machine.nix`/scripts over prose when they conflict.
- Scratch dir for experiments: `/tmp/opencode`.

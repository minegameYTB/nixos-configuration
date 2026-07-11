# ISO Profiles

## Overview

Two ISO variants built from the flake:
- **GNOME** — desktop environment with browser, sound, NetworkManager, SSH
- **CLI** — headless environment with NetworkManager, SSH

Both include the `nixos-config-install` command — open a terminal and run it to start the installation wizard.

## Architecture

```
machine.nix            # defines iso-gnome / iso-minimal nixosSystem
  └─ lib/default.nix   # re-exports iso/common.nix helpers
       └─ iso/common.nix   # mkIsoConfig, keyboard helpers, welcome message
            ├─ iso/gnome.nix   # GNOME-only: imports, autologin, keyboard-session-apply
            └─ iso/cli.nix     # CLI-only: marker, console keymap
```

### `iso/common.nix`
Shared ISO configuration:
- `mkIsoConfig` — NixOS module adding all shared config (networking, services, ZFS, users, ISO naming, keyboard setup)
- `layouts` — list of `{ layout, keymap, locale, label }` for keyboard specialisations
- `mkKeyboardSpec` — creates a GRUB specialisation entry per layout
- `mkWelcomeMessage` — shell welcome banner for each edition
- `keyboardSetupScript` — systemd oneshot service: reads kernel cmdline params, applies keymap + Xorg + dconf
- `keyboardSessionScript` — applies keyboard layout to the GNOME session (used by GNOME profile only)

### `iso/gnome.nix` (24 lines)
Minimal profile — only:
- imports GNOME desktop, sound, browser
- calls `mkIsoConfig` for shared config
- sets autologin for `nixos` user
- registers `keyboard-session-apply` systemd user service (re-applies keyboard layout after GNOME session start)

### `iso/cli.nix` (11 lines)
Even smaller — only:
- calls `mkIsoConfig`
- sets console keymap to `fr`

## Building

```bash
nix build '.#iso-gnome'              # GNOME desktop ISO
nix build '.#iso-minimal'            # Minimal CLI ISO
```

The resulting image is at `result/iso/nixos-*.iso`:

```bash
sudo dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

## Naming convention

`nixos-<release>.<shortRev>.<branch>-<edition>.iso`

Examples:
```
nixos-26.05.a1b2c3d.main-GNOME.iso
nixos-26.05.e5f6g7h.fix-ssh-CLI.iso
```

The `volumeID` follows: `nixos-<edition>-<branch>-<release>` (max 32 chars).

## Keyboard specialisations

Two layouts available at the GRUB menu:

| Entry | Layout | Keymap | Locale |
|---|---|---|---|
| US English | `us` | `us` | `en_US.UTF-8` |
| French (default) | `fr` | `fr` | `fr_FR.UTF-8` |

The default (no specialisation selected) boots with French layout.

On GNOME ISO, the keyboard layout is re-applied after GNOME session start via `keyboard-session-apply` (gsettings dconf dance). The setup service (`keyboard-setup`) runs before the display manager and configures:
- Console keymap (`loadkeys`)
- Xorg config (`/etc/X11/xorg.conf.d/00-keyboard.conf`)
- dconf for GDM and all home directories

## Pre-installed packages

Both ISOs include `nixos-config` (the installer package with `nixos-config-install` command).

GNOME ISO additionally includes `keyboard-session-apply` (GNOME session keyboard re-apply script).

## Build speed

The bottleneck is squashfs compression. This config uses `zstd` instead of the default `xz` — ~3× faster for ~5% larger image. To tune further, change `isoImage.squashfsCompression` in `iso/common.nix`:

| Compression | Time (relative) | Size |
|---|---|---|
| `lz4` | ×1 | 59% |
| `zstd` | ×1.5 | 48% |
| `gzip` | ×2.1 | 49% |
| `xz -Xdict-size 100%` (nixpkgs default) | ×4.5 | 43% |

## Kernel

Both ISOs use the CachyOS kernel:
- **GNOME** — `linux_cachyos-lto` (bore scheduler)
- **CLI** — `linux_cachyos-server-lto` (server-optimised LTS-like)

ZFS is supported via the CachyOS kernel package (`zfs_cachyos`).

## GRUB label

Menu entry format: `NixOS <edition> (<branch>)`
- `NixOS GNOME (main)`
- `NixOS CLI (fix-ssh)`

With keyboard specialisation sub-entries:
- `NixOS GNOME (main) - US English`
- `NixOS GNOME (main) - French (default)`

## Creating new variants

Three places to touch. The existing files are the best templates — use them directly.

### 1. `iso/<variant>.nix` — the ISO profile module

Two real-world templates to follow:

**For a desktop variant** → copy `iso/gnome.nix`:

```nix
{ lib, pkgs, config, keyboardSetupScript, keyboardSessionScript,
  welcomeMessage, rev, branch, edition, mkIsoConfig, ... }: {
  imports = [
    # Desktop-specific NixOS modules
    ../configurations/configs/specific/desktop/environment/gnome.nix
    ../configurations/configs/specific/desktop/sound.nix
    ../configurations/configs/specific/desktop/browser

    # Shared ISO config from common.nix
    (mkIsoConfig { inherit edition rev branch welcomeMessage keyboardSetupScript keyboardSessionScript; })
  ];

  marker.hostProfile = "desktop";
  marker.archProfile = "x86-64-v1";

  console.keyMap = "fr";
  services.xserver.xkb.layout = "fr";

  services.displayManager.autoLogin = { enable = true; user = "nixos"; };
}
```

- Replace the desktop modules (`gnome.nix`, `sound.nix`, `browser`) with the ones your variant needs.
- `keyboardSessionScript` is only needed if your DE requires a post-session keyboard re-apply (GNOME does). If yours doesn't, change the `mkIsoConfig` call to `keyboardSessionScript = null;` and drop the `keyboard-session-apply` user service.
- `marker.hostProfile` drives kernel selection — `desktop` picks CachyOS LTO (bore), `server` picks CachyOS LTS.

**For a CLI/headless variant** → copy `iso/cli.nix`:

```nix
{ lib, pkgs, config, keyboardSetupScript,
  welcomeMessage, rev, branch, edition, mkIsoConfig, ... }: {
  imports = [
    (mkIsoConfig { inherit edition rev branch welcomeMessage keyboardSetupScript; })
  ];

  marker.hostProfile = "server";
  marker.archProfile = "x86-64-v1";

  console.keyMap = "fr";
}
```

No `keyboardSessionScript`, no autologin, no display manager — just the shared config plus a marker.

### 2. `machine.nix` — register the `nixosSystem`

Just add a call to `helpers.iso.mkIso` next to the existing ones:

```nix
iso-<name> = helpers.iso.mkIso {
  edition = "<NAME>";
  profile = ./iso/<variant>.nix;
  hostname = "nixos-iso-<name>";
  hmProfile = ./hm-profiles/<profile>.nix;
  hmExtraModules = [ ./home-manager/configs/specific/nixos ];  # desktop only
  keyboardSession = false;  # set true for DEs needing post-session keyboard re-apply
  extraModules = [ ];  # optional extra NixOS modules (e.g. cuda.nix, vm-host.nix)
};
```

No `specialArgs`, no `nixosSystem`, no `overlay`, no `home-manager` wiring — all handled by `mkIso`.
Option relative to iso is here "https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/cd-dvd/iso-image.nix#L558"

Key differences between the existing two:

| | `iso-gnome` | `iso-minimal` |
|---|---|---|
| Profile file | `./iso/gnome.nix` | `./iso/cli.nix` |
| HM profile | `desktop-profile-wrapped.nix` | `server-profile.nix` |
| `hmExtraModules` | `[ ./home-manager/configs/specific/nixos ]` | omitted |
| `keyboardSession` | `true` | omitted (defaults to `false`) |
| `extraModules` | omitted | omitted |
| `hostname` | `nixos-iso` | `nixos-iso-minimal` |

### 3. `flake.nix` — auto-discovery

Nothing to do. Any config starting with `iso-` in `machine.nix` is automatically picked up and exposed as a flake package via `filterAttrs` + `mapAttrs'`.

### Build

```bash
nix build '.#iso-<name>'
```

### Summary

- `mkIsoConfig` provides all shared config (naming, networking, ZFS, users, keyboard setup) — your variant module only needs to add what is specific.
- `keyboardSessionScript` is for DEs that need a post-session keyboard layout re-apply. Pass it in `isoSpecialArgs` and add it to the `mkIsoConfig` call. CLI variants skip it entirely.
- `edition` flows into the ISO filename, `volumeID`, GRUB label, and welcome message — keep it short and uppercase.

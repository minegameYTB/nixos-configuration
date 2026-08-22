# /dev/disk/by-fs — Aliases by filesystem type

## Role

Creates a FreeBSD-style alias hierarchy, grouped **by filesystem type** then by stable
identifier, in `/dev/disk/` (standard udev namespace). The subdirectories mirror the
standard `/dev/disk/` naming (`by-uuid/`, `by-label/`, `by-partuuid/`, `by-partlabel/`):

```
/dev/disk/by-fs/<fstype>/fs-uuid/<uuid>      (filesystem UUID — equivalent to FreeBSD's /dev/ufsid/)
/dev/disk/by-fs/<fstype>/partuuid/<partuuid>  (GPT partition UUID — equivalent to /dev/gptid/)
/dev/disk/by-fs/<fstype>/label/<label>        (filesystem label — reproducible)
/dev/disk/by-fs/<fstype>/partlabel/<label>    (GPT partition name — equivalent to /dev/gpt/, reproducible)
```

The subdirectory indicates the identifier source:

- `fs-uuid/<uuid>` — filesystem UUID (`ID_FS_UUID`, set by blkid). Unique and reliable,
  but **not reproducible**: re-creating the filesystem changes the UUID.
- `partuuid/<partuuid>` — GPT partition entry UUID (`ID_PART_ENTRY_UUID`). Unique, not reproducible.
- `label/<label>` — filesystem label (`ID_FS_LABEL`, set by blkid). **Reproducible**:
  set the label at filesystem creation (e.g. `mkfs.btrfs -L DATA` or in disko) and the
  link is identical every time the disk is recreated.
- `partlabel/<label>` — GPT partition name (`ID_PART_ENTRY_NAME`). **Reproducible**:
  set the name at partition creation (disko names partitions `disk-<disk>-<part>`).

The `fs-uuid/` and `partuuid/` links are created for every partition with a filesystem;
`label/` only when the filesystem actually has a label, `partlabel/` when the GPT
partition has a name. For reproducible mounts (that survive a recreated disk),
reference the `label/` or `partlabel/` link.

Examples:

```
/dev/disk/by-fs/btrfs/fs-uuid/066b7939-c694-408c-8e92-1dca2514f0ba
/dev/disk/by-fs/btrfs/label/DATA
/dev/disk/by-fs/btrfs/partuuid/368a319b-e821-4e75-aa7b-65d0562e3ac3
/dev/disk/by-fs/vfat/label/EFI
/dev/disk/by-fs/vfat/fs-uuid/05DA-DE1D
/dev/disk/by-fs/vfat/partuuid/8fb6e131-b280-432d-a43c-d7078ef36c1b
/dev/disk/by-fs/crypto_LUKS/partlabel/disk-main-luks
/dev/disk/by-fs/zfs_member/fs-uuid/2888783311124382195
/dev/disk/by-fs/zfs_member/partuuid/33089275-704e-4f7e-be65-34d5213dab91
/dev/disk/by-fs/zfs_member/label/zroot
/dev/disk/by-fs/swap/fs-uuid/b250506a-8e0f-4380-a558-5caa9ee03859
```

## Mechanism

Implemented by `configurations/configs/common/system-opts/disk-symlinks.nix`:
four udev rules added **at runtime** (`services.udev.extraRules` → `99-local.rules`)
and **to the initrd** (`boot.initrd.services.udev.rules`).

1. `60-persistent-storage.rules` (shipped by systemd) runs `blkid` and sets
   `ID_FS_TYPE`, `ID_FS_UUID`, `ID_PART_ENTRY_UUID`, `ID_FS_LABEL`, `ID_PART_ENTRY_NAME`
   on the device event.
2. `99-local.rules` then runs and creates the symlinks via `SYMLINK+=`,
   with `$env{...}` in the path. `ENV{...}=="?*"` guarantees a non-empty value
   (no broken link to an empty path).
3. udev automatically creates the intermediate directories and removes the links
   when the device disappears (hotplug / boot).

The `by-fs` links are **independent** symlinks to the real node (`/dev/sda1`),
alongside `by-uuid`/`by-partuuid`/`by-id` — they do not point to those links.

### Why the initrd

`services.udev.extraRules` applies **only** at runtime. But the root ZFS pool import
happens in the initrd, before `/` is mounted. For `/dev/disk/by-fs` to exist at that
point, the rules are duplicated into `boot.initrd.services.udev.rules`
(option of type `lines` → concatenates, does not replace nixpkgs' default dm rule).
The initrd already bundles `60-persistent-storage.rules`, so blkid runs there and
`ID_FS_*` are available.

## Uses

- Glob by type in a script:
  ```
  for d in /dev/disk/by-fs/zfs_member/fs-uuid/*; do ...
  ```
- List present FS types: `ls /dev/disk/by-fs/`
- Targeted ZFS import limited to its members:
  ```
  zpool import -d /dev/disk/by-fs/zfs_member/fs-uuid
  ```

## Verification

On a machine with active udev:

```
sudo nixos-rebuild switch
udevadm trigger && udevadm settle
ls -l /dev/disk/by-fs/
```

## Notes

- No conflict: `extraRules`/`boot.initrd.services.udev.rules` (type `lines`)
  concatenate the rules of other modules (`zfs-common.nix`, `games/default.nix`, ...).
- Directory names = raw blkid values (`zfs_member`, `crypto_LUKS`, `swap`, ...);
  subdirectories mirror the standard `/dev/disk/` naming (`fs-uuid/`, `partuuid/`,
  `label/`, `partlabel/`). A label/name must be unique per type — two filesystems of
  the same type with the same label collide. Avoid spaces or slashes in labels/names
  (they break udev paths).
- **Level 2 (implemented)**: `boot.zfs.devNodes` is set to
  `/dev/disk/by-fs/zfs_member/fs-uuid` in `configurations/hardware-configuration/filesystem/zfs/default.nix`
  → the ZFS scan only walks the member partitions (filtered by type).
  Requires a real boot test (the import happens in the initrd); the links exist there
  thanks to `boot.initrd.services.udev.rules`.
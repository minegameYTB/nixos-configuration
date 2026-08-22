{ pkgs, ... }:

let
  ### Common rules for runtime + initrd to avoid duplication.
  ### Link names use subdirectories mirroring the standard /dev/disk/ namespace:
  ###   fs-uuid/<uuid>      filesystem UUID (ID_FS_UUID, set by blkid) — unique, not reproducible
  ###   partuuid/<partuuid> GPT partition entry UUID (ID_PART_ENTRY_UUID) — unique, not reproducible
  ###   label/<label>       filesystem label (ID_FS_LABEL) — reproducible, set at filesystem creation
  ###   partlabel/<label>   GPT partition name (ID_PART_ENTRY_NAME) — reproducible, set at partition creation
  byFsRules = ''
    # For by-fs namespace:
    ACTION=="change", SUBSYSTEM=="block", RUN+="${pkgs.bash}/bin/bash -c '${pkgs.findutils}/bin/find /dev/disk/by-fs -lname \"*/$env{DEVNAME##*/}\" -delete'"

    SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="?*", ENV{ID_FS_UUID}=="?*", SYMLINK+="disk/by-fs/$env{ID_FS_TYPE}/fs-uuid/$env{ID_FS_UUID}"
    SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ENV{ID_FS_TYPE}=="?*", ENV{ID_PART_ENTRY_UUID}=="?*", SYMLINK+="disk/by-fs/$env{ID_FS_TYPE}/partuuid/$env{ID_PART_ENTRY_UUID}"
    SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="?*", ENV{ID_FS_LABEL}=="?*", SYMLINK+="disk/by-fs/$env{ID_FS_TYPE}/label/$env{ID_FS_LABEL}"
    SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ENV{ID_FS_TYPE}=="?*", ENV{ID_PART_ENTRY_NAME}=="?*", SYMLINK+="disk/by-fs/$env{ID_FS_TYPE}/partlabel/$env{ID_PART_ENTRY_NAME}"

    ACTION=="remove", SUBSYSTEM=="block", RUN+="${pkgs.findutils}/bin/find -L /dev/disk/by-fs -type l -delete"
    SUBSYSTEM=="block", RUN+="${pkgs.findutils}/bin/find /dev/disk/by-fs -type d -empty -delete"
  '';
in
{
  ### FreeBSD-style aliases grouped by filesystem type:
  ###   /dev/disk/by-fs/<fstype>/fs-uuid/<uuid>      (equivalent to /dev/ufsid/)
  ###   /dev/disk/by-fs/<fstype>/partuuid/<partuuid>  (equivalent to /dev/gptid/)
  ###   /dev/disk/by-fs/<fstype>/label/<label>        (reproducible)
  ###   /dev/disk/by-fs/<fstype>/partlabel/<label>    (equivalent to /dev/gpt/, reproducible)
  ### ID_FS_TYPE / ID_FS_UUID / ID_PART_ENTRY_UUID / ID_FS_LABEL / ID_PART_ENTRY_NAME are set by blkid
  ### in 60-persistent-storage.rules, run before 99-local.rules.

  ### Runtime: system udev (services.udev.extraRules -> 99-local.rules)
  services.udev.extraRules = byFsRules;

  ### Initrd: same rules so that /dev/disk/by-fs exists as soon as ZFS is imported
  ### (before the mount of /). The option is of type "lines" -> concatenates
  ### (does not replace) the default dm rule from nixpkgs.
  ### The initrd already bundles 60-persistent-storage.rules, so blkid runs there
  ### and ID_FS_* are available.
  boot.initrd.services.udev.rules = byFsRules;
}

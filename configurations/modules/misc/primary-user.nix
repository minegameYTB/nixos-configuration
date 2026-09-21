# configurations/modules/misc/primary-user.nix — canonical primary
# interactive user for NixOS host modules.
#
# Single source of truth: derive it here, consume it via
# config.users.primaryUser everywhere else (fix-xdg-user-dirs,
# desktop autologin, ...). Do NOT re-derive it inline with
# lib.head/lib.filter — that duplication already diverged once.
# First normal user wins (lib.attrNames is sorted); a machine with
# no normal user fails evaluation loudly instead of picking silently.
{ lib, config, ... }:
{
  options.users.primaryUser = lib.mkOption {
    type = lib.types.str;
    description = "Primary interactive user: first normal user. Single source of truth — consume via config.users.primaryUser instead of re-deriving it.";
  };

  config.users.primaryUser = lib.head (
    lib.filter (u: config.users.users.${u}.isNormalUser or false) (lib.attrNames config.users.users)
  );
}

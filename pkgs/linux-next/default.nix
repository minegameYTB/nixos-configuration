# Linux-next test kernel, pinned to a single commit.
#
# Moving target by nature (new -next every day): refresh the pin with
#   ./update.sh --write   (in this directory)
#
# `version` MUST match the real kernelrelease
# (VERSION.PATCHLEVEL.SUBLEVEL + EXTRAVERSION + localversion-next),
# otherwise the build fails with "modDirVersion ... is wrong, it should be: ...".
{
  lib,
  fetchgit,
  buildLinux,
  ...
}@args:

buildLinux (
  args
  // rec {
    version = "7.3.0-rc5-next-20261002";
    modDirVersion = version;

    src = fetchgit {
      url = "https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git";
      rev = "f0406245cb9855e6318335a8a223551354291a46";
      hash = "sha256-LBmst40wGhhFC6o6fz9l7f0cMR9y4guGmCpTkdmMgvI=";
      # Shallow: fetch only the pinned rev, not the whole history.
      deepClone = false;
    };

    kernelPatches = [ ];

    # No CachyOS patches/options here on purpose: they don't apply to -next.
    # NixOS common-config.nix stays enabled (default) so systemd/initrd
    # requirements are covered; tolerate options that -next renamed/removed.
    ignoreConfigErrors = true;

    extraMeta.branch = "linux-next";
  }
  // (args.argsOverride or { })
)

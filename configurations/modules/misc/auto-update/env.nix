# configurations/modules/misc/auto-update/env.nix — tight
# per-service runtime envs. Each derivation exposes a single
# $out/bin with *only* the binaries the assembled bash actually
# calls (checked by test-shell-paths.sh). No host PATH is ever
# inherited. Explicit symlinks keep the closure minimal while
# preserving the binaries' original RPATHs to their libs.
#
# Audit: every bare invocation in the assembled scripts was traced
# (see test-shell-paths.sh CANDS + debug.nix findmnt/df/awk). Only
# those binaries are kept — no cp/dirname/numfmt/tail/wc/gawk/diff
# etc. that are only ever invoked via absolute ${pkgs.*}/bin/* or
# are shell builtins (printf).
#
# Build / inspect independently (no full system rebuild):
#   nix build '.#nixos-auto-update-env-main' && ls -1 result/bin  # 41
#   nix build '.#nixos-auto-update-env-health' && ls -1 result/bin # 21
#   make env  # all tiers + system-wired PATHs
#   nix eval --raw '.#nixosConfigurations.vm-desktop-efi.config.systemd.services.nixos-auto-update.environment.PATH'
{
  pkgs,
  config,
  lib,
}:
let
  mkEnv =
    name: bins:
    pkgs.runCommand name { } ''
      mkdir -p "$out/bin"
      ${lib.concatMapStrings (b: "ln -s ${b} \"$out/bin/${builtins.baseNameOf b}\"\n") bins}
    '';

  # Common core (intersection of all services): 10 binaries.
  coreBins = with pkgs; [
    "${coreutils}/bin/base64"
    "${coreutils}/bin/cat"
    "${coreutils}/bin/chmod"
    "${coreutils}/bin/date"
    "${coreutils}/bin/mkdir"
    "${coreutils}/bin/mktemp"
    "${coreutils}/bin/mv"
    "${coreutils}/bin/stat"
    "${coreutils}/bin/sync"
    "${coreutils}/bin/test"
  ];

  pendingBins = coreBins ++ [
    "${pkgs.libnotify}/bin/notify-send"
  ];

  rootBins = coreBins ++ [
    "${pkgs.coreutils}/bin/basename"
    "${pkgs.coreutils}/bin/env"
    "${pkgs.coreutils}/bin/id"
    "${pkgs.coreutils}/bin/rm"
    "${pkgs.coreutils}/bin/timeout"
    "${pkgs.util-linux.bin}/bin/runuser"
    "${pkgs.libnotify}/bin/notify-send"
  ];

  healthBins = coreBins ++ [
    "${pkgs.coreutils}/bin/basename"
    "${pkgs.coreutils}/bin/env"
    "${pkgs.coreutils}/bin/id"
    "${pkgs.coreutils}/bin/readlink"
    "${pkgs.coreutils}/bin/rm"
    "${pkgs.coreutils}/bin/timeout"
    "${pkgs.util-linux.bin}/bin/flock"
    "${pkgs.util-linux.bin}/bin/runuser"
    "${pkgs.libnotify}/bin/notify-send"
    "${config.systemd.package}/bin/systemctl"
    "${pkgs.gnugrep}/bin/grep"
  ];

  mainBins = coreBins ++ [
    "${pkgs.coreutils}/bin/basename"
    "${pkgs.coreutils}/bin/cut"
    "${pkgs.coreutils}/bin/df"
    "${pkgs.coreutils}/bin/env"
    "${pkgs.coreutils}/bin/head"
    "${pkgs.coreutils}/bin/id"
    "${pkgs.coreutils}/bin/readlink"
    "${pkgs.coreutils}/bin/rm"
    "${pkgs.coreutils}/bin/seq"
    "${pkgs.coreutils}/bin/sha256sum"
    "${pkgs.coreutils}/bin/sleep"
    "${pkgs.coreutils}/bin/timeout"
    "${pkgs.coreutils}/bin/touch"
    "${pkgs.util-linux.bin}/bin/findmnt"
    "${pkgs.util-linux.bin}/bin/flock"
    "${pkgs.util-linux.bin}/bin/runuser"
    "${pkgs.libnotify}/bin/notify-send"
    "${config.systemd.package}/bin/systemctl"
    # nixos-rebuild-ng wraps switch-to-configuration in systemd-run when
    # systemd is up (nix.py SWITCH_TO_CONFIGURATION_CMD_PREFIX). Without
    # it, boot fails with [Errno 2] right after the test check passes.
    "${config.systemd.package}/bin/systemd-run"
    "${config.nix.package}/bin/nix"
    "${config.nix.package}/bin/nix-env"
    # Edge-case insurance (zero new closure: same nix package): classic,
    # remote-tmpdir and channel paths of nixos-rebuild-ng call these;
    # a nixpkgs refactor moving a call onto our flake path must not Errno 2.
    # ssh/nix-copy-closure (remote-only) and nano/$EDITOR (edit action) stay
    # out on purpose — unreachable from build/boot local service.
    "${config.nix.package}/bin/nix-store"
    "${config.nix.package}/bin/nix-build"
    "${config.nix.package}/bin/nix-instantiate"
    "${config.system.build.nixos-rebuild}/bin/nixos-rebuild"
    "${pkgs.gitMinimal}/bin/git"
    "${pkgs.diffutils}/bin/cmp"
    "${pkgs.curl}/bin/curl"
    "${pkgs.gawk}/bin/awk"
    "${pkgs.gnused}/bin/sed"
    "${pkgs.nvd}/bin/nvd"
  ];
in
{
  core = mkEnv "nixos-auto-update-core-env" coreBins;
  pending = mkEnv "nixos-auto-update-pending-env" pendingBins;
  root = mkEnv "nixos-auto-update-root-env" rootBins;
  health = mkEnv "nixos-auto-update-health-env" healthBins;
  main = mkEnv "nixos-auto-update-main-env" mainBins;
}

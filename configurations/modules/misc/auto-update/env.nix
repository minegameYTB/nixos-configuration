# configurations/modules/misc/auto-update/env.nix — tight
# per-service runtime envs. Each derivation exposes a single
# $out/bin with *only* the binaries the assembled bash actually
# calls (checked by test-shell-paths.sh). No host PATH is ever
# inherited. Explicit symlinks keep the closure minimal while
# preserving the binaries' original RPATHs to their libs.
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

  coreBins = with pkgs; [
    "${coreutils}/bin/base64"
    "${coreutils}/bin/basename"
    "${coreutils}/bin/cat"
    "${coreutils}/bin/chmod"
    "${coreutils}/bin/cp"
    "${coreutils}/bin/cut"
    "${coreutils}/bin/date"
    "${coreutils}/bin/df"
    "${coreutils}/bin/dirname"
    "${coreutils}/bin/env"
    "${coreutils}/bin/head"
    "${coreutils}/bin/id"
    "${coreutils}/bin/mkdir"
    "${coreutils}/bin/mktemp"
    "${coreutils}/bin/mv"
    "${coreutils}/bin/numfmt"
    "${coreutils}/bin/printf"
    "${coreutils}/bin/readlink"
    "${coreutils}/bin/rm"
    "${coreutils}/bin/seq"
    "${coreutils}/bin/sha256sum"
    "${coreutils}/bin/sleep"
    "${coreutils}/bin/stat"
    "${coreutils}/bin/sync"
    "${coreutils}/bin/tail"
    "${coreutils}/bin/timeout"
    "${coreutils}/bin/touch"
    "${coreutils}/bin/wc"
  ];

  rootBins = coreBins ++ [
    "${pkgs.util-linux.bin}/bin/flock"
    "${pkgs.util-linux.bin}/bin/runuser"
    "${pkgs.util-linux.bin}/bin/findmnt"
    "${pkgs.libnotify}/bin/notify-send"
  ];

  healthBins = rootBins ++ [
    "${config.systemd.package}/bin/systemctl"
    "${pkgs.gnugrep}/bin/grep"
  ];

  pendingBins = coreBins ++ [
    "${pkgs.libnotify}/bin/notify-send"
  ];

  mainBins = healthBins ++ [
    "${config.nix.package}/bin/nix"
    "${config.nix.package}/bin/nix-env"
    "${config.system.build.nixos-rebuild}/bin/nixos-rebuild"
    "${pkgs.gitMinimal}/bin/git"
    "${pkgs.diffutils}/bin/cmp"
    "${pkgs.diffutils}/bin/diff"
    "${pkgs.curl}/bin/curl"
    "${pkgs.gawk}/bin/awk"
    "${pkgs.gawk}/bin/gawk"
    "${pkgs.gnused}/bin/sed"
    "${pkgs.nvd}/bin/nvd"
  ];
in
{
  core = mkEnv "nixos-auto-update-core-env" coreBins;
  root = mkEnv "nixos-auto-update-root-env" rootBins;
  health = mkEnv "nixos-auto-update-health-env" healthBins;
  pending = mkEnv "nixos-auto-update-pending-env" pendingBins;
  main = mkEnv "nixos-auto-update-main-env" mainBins;
}

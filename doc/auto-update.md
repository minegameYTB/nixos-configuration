# Auto-update

GLF-OS style automatic system updates: a machine follows the CI-composed *buffer* branch, bumps flake inputs, and stages the new generation with `nixos-rebuild boot` (no immediate activation). Opt-in per machine, off by default.

Module: `configurations/modules/misc/auto-update/` (options under `system.autoUpdate.*`).
CI: `.github/workflows/flake-autoupdate.yml` (see Lifecycle below).

Layout (one concern per file, contracts in each header): `default.nix`
(options + assertions), `services.nix` (systemd assembly + main flows),
`env.nix` (tight per-service `$out/bin` envs, single `PATH` entry per
service), `debug.nix` (verbose logging + dry-run transaction tests),
`errors.nix` (CODE → FR/EN catalogue, single source of truth for messages),
`output.nix` (status, logging, git filter), `notifier.nix` (immediate +
deferred bilingual notifications), `transaction.nix` (lock, traps, phases,
recovery, `_fail`), `sync.nix` (channel force-sync, flake inputs, rebuild),
`health.nix` (post-boot validation, the `validating` phase).

## Runtime envs (`env.nix`)

Each service gets a single `$out/bin` (no host `PATH` inherited) built by `env.nix` via `pkgs.runCommand` with explicit `ln -s` per binary — the closure stays minimal while the binaries keep their original store RPATHs to their libs. Three tiers (audit of every bare invocation in `configurations/modules/misc/auto-update/*.nix`, checked by `test/test-shell-paths.sh`):

- `core` (11): `base64 cat chmod date mkdir mktemp mv stat sync test notify-send`
- `health` (21): `core` + `basename env id readlink rm timeout flock runuser systemctl grep`
- `main` (39): `core` + `basename cut df env head id readlink rm sha256sum sleep timeout touch flock runuser systemctl systemd-run nix nix-env nix-store nix-build nix-instantiate nixos-rebuild git cmp curl awk sed nvd`

Only bare invocations that rely on `PATH` are kept — absolute `${pkgs.*}/bin/*` calls and shell builtins (`printf`) are excluded. `services.nix` wires them as `pathCore` (per-user pending service), `pathHealth` (healthcheck + notify-failure services), `pathMain` (updater service).

`main` also covers nixos-rebuild-ng's own subprocess calls (audited from its 26.11 Python source — `test/test-auto-update-env-runtime.sh` pins them). Python has no shell, so bash builtins don't help: `test` (`set_profile`, `switch_to_configuration` — the 2026-09-20 `rebuild-boot` incident), `systemd-run` (boot prefix when systemd is up), `mkdir`/`nix-env` (profile set), `env -i` (elevated runs), plus `nix-store`/`nix-build`/`nix-instantiate` as edge-case insurance. `ssh`/`nix-copy-closure` (remote-only) and `$EDITOR` (edit action) stay out — unreachable from build/boot.

Build / inspect independently (no full system rebuild):

```bash
# which env will the service see? (system-wired, single PATH)
nix eval --raw '.#nixosConfigurations.vm-desktop-efi.config.systemd.services.nixos-auto-update.environment.PATH'
nix eval --raw '.#nixosConfigurations.vm-desktop-efi.config.systemd.user.services.nixos-auto-update-notify-pending.environment.PATH'

# what is inside each env? — standalone flake packages (no system eval)
nix build '.#nixos-auto-update-env-main'  && ls -1 result/bin | tr '\n' ' ' # 39
nix build '.#nixos-auto-update-env-health' && ls -1 result/bin | tr '\n' ' ' # 21
nix build '.#nixos-auto-update-env-core'   && ls -1 result/bin | tr '\n' ' ' # 11
# or all at once:
make env

# PATH hygiene guards (must stay green):
bash test/test-shell-paths.sh
bash test/test-auto-update-env-runtime.sh

## How it works

Each timer run (`nixos-auto-update.service`, oneshot, low CPU/IO priority, skipped on battery via `ConditionACPower` unless `requireACPower = false`). The timer is monotonic (`OnBootSec` + `OnUnitInactiveSec`, default every 2 days) — cadence drifts by design, no wall-clock anchoring. Pre-checks first: free disk on `/nix/store`, internet connectivity with wait + retries, per-phase `timeouts.*`; a colliding run exits `75` (stays green).

Smart behavior — unchanged state costs nothing:

1. **Source** — the channel revision is resolved fresh via `git ls-remote` (no nix tarball-cache staleness), then the machine-owned mirror clone in `/var/lib/nixos-auto-update/flake` is force-synced (`git fetch --force --depth 1 --update-shallow` + `reset --hard` + `clean -fdx`, verified against the resolved rev). The force-sync follows channel force-pushes (soak advances, phase jumps). Any incremental failure falls back to a fresh `git clone --depth 1 --no-tags` into `flake.new` + atomic `mv` (the previous tree is only dropped after the new one verifies). Tags are never fetched (`--no-tags` everywhere).
2. **Skip** — `(source-rev, lock-hash)` identical to the last fully successful run → exit immediately: no update, no rebuild, no generation spam.
3. **Build** — the channel tree is built tel quel, exactly as validated (`nixos-rebuild boot --flake <ref>#<configuration> --print-build-logs`). Explicit `--flake` is respected by the repo's `nixos-rebuild` wrapper (no auto-injection). Followed by an `nvd diff` summary between the previous profile generation and the staged profile — same generation resolution as the `report-changes` activation hook (`nix-env --list-generations`, incremental across double-stages). Failure keeps the running generation and logs an error (failures always notify, see below).
4. **Reboot** — only when the new generation changes `kernel` or `init`, and only when `allowReboot = true`. Otherwise a "reboot required / staged" notice is emitted — once per generation (see anti-spam).

No garbage collection is performed (default nix behavior kept); rollback uses the 30 kept boot entries plus snapper/sanoid snapshots.

## Options

| Option | Default | Description |
|---|---|---|
| `enable` | `false` | Opt-in per machine profile. |
| `channel` | `"flake-autoupdate"` | Last soaked-green source commit followed (not the local `.branch`). |
| `configuration` | `null` (required) | `nixosConfigurations.<name>` to build — intentionally not `networking.hostName`. |
| `checkInterval` | `"1d"` | Check cadence (`OnUnitInactiveSec`, from previous run's end). Daily absorbs manual rev bumps (every 3-4 days) within a day. |
| `startDelay` | `"5min"` | First-check delay after boot (`OnBootSec`). Short like GLF-OS (`1min`) for prompt catch-up. |
| `randomizedDelay` | `"10min"` | Jitter per trigger (spread a fleet). Added on top of `startDelay` at boot, so worst case the first check runs ~15min after boot. |
| `allowReboot` | `false` | Reboot automatically on kernel/init change. |
| `requireACPower` | `true` | Only run on AC power (`ConditionACPower`). Set `false` on transportables that are effectively always plugged in. |
| `notify` | `true` | Desktop notification on success/failure (see below). |
| `notifyIcon` | `"nix-snowflake-white"` | Icon name for desktop notifications. |
| `notifyTimeout` | `10000` | Display time in milliseconds. Honored by most servers; GNOME caps custom timeouts. |
| `logFile` | `"/var/log/nixos-auto-update.log"` | Persistent text log (journald stays the binary source of truth). Rotated by logrotate (daily, 7 kept). |
| `minDiskGB` | `10` | Minimum free space on `/nix/store` (GiB) to start a run. |
| `timeouts.lsRemote` | `"5m"` | Budget for `git ls-remote` channel resolution. |
| `timeouts.fetch` | `"10m"` | Budget for the incremental channel force-sync. |
| `timeouts.clone` | `"30m"` | Budget for a fresh channel clone (fallback). |
| `timeouts.build` | `"1h"` | Budget for `nixos-rebuild build`. |
| `timeouts.boot` | `"1h"` | Budget for `nixos-rebuild boot` / `switch-to-configuration boot`. |
| `timeouts.internetWait` | `600` | How long to wait for connectivity (seconds) before giving up. |
| `healthCheck.enable` | `= enable` | Validate staged generations after boot. |
| `healthCheck.units` | desktop `display-manager`, else `sshd` | Units that must be active after a staged boot. |
| `healthCheck.requireNetwork` | `true` | Require a default IPv4 route (loopback excluded). |
| `healthCheck.checkFailedUnits` | `true` | Fail validation when any unit is failed (essential-boot signal). |
| `healthCheck.autoRollback` | `false` | Restore the previous healthy system as next boot generation on unhealthy staged boot (one-shot per staged generation; inhibit gate kept — human must clear it). |
| `healthCheck.timeout` | `120` | Per-check budget in seconds. |

Example (test VM profile):

```nix
system.autoUpdate = {
  enable = true;
  configuration = "vm-cli-efi";
};
```

## Notifications

Journal (`journalctl -u nixos-auto-update.service`) is always written and is the source of truth; `logFile` keeps the persistent text copy. Every substantive line goes through `_status` (fd 5) or `_prefix_lines` (streamed command output: rebuild logs, `nvd` diff): uniform `[LEVEL]` lines under a single PID per run in both sinks, ANSI control sequences stripped. Desktop `notify-send` is best-effort, bilingual (FR/EN by session `LANG`), with a double gate:

- **Eval time**: real DE installed (`services.desktopManager.gnome.enable`), not just `marker.hostProfile`. Servers and headless profiles stay journal-only (failures are queued, never lost).
- **Runtime**: an active graphical session must own `/run/user/<uid>/bus` (user other than `gdm`); otherwise the bilingual notification is queued in `/var/lib/nixos-auto-update/pending-notification` and delivered at the next graphical login by the per-user `nixos-auto-update-notify-pending.service` (dedup by id).
- **Failures**: a crash before notifying is covered by `nixos-auto-update-notify-failure.service` (`onFailure`), which reads the machine-readable CODE from the state file and notifies (or queues) accordingly.
- **Anti-spam**: each generation notifies at most once — re-runs on an unchanged tree stay journal-only. Failures always notify.
- Icon: `notifyIcon` (default `nix-snowflake-white` monochrome, from the hicolor theme — rendered with the title by GNOME Shell).
- Branding: `--app-name="NixOS"` puts "NixOS" in the header (instead of "notify-send") with the event as title. A header *icon* would require a `.desktop` entry shipping the snowflake — none exists, so the icon stays with the title.

## Error catalogue

Every failure goes through `_fail CODE [detail]` (see `errors.nix`, the single source of truth — edit messages there, never in the fragments). The CODE lands in the journal, the state file (`failed|<date>|<CODE>|pending|notified`), and the notification:

| CODE | Meaning |
|---|---|
| `channel-resolve` | `git ls-remote` empty/failed — network or forge unreachable. |
| `flake-sync` | Incremental force-sync then fresh clone both failed. |
| `flake-lock-missing` | Synced tree has no `flake.lock`. |
| `rebuild-boot` | `nixos-rebuild boot` failed — running generation kept. |
| `disk-space` | `/nix/store` below `minDiskGB`. |
| `network-offline` | No connectivity after `timeouts.internetWait`. |
| `state-error` | Internal state unreadable/corrupt — manual action. |
| `boot-recovery` | Interrupted-transaction recovery incomplete — retried next run. |
| `boot-recovery-rolled-back` | Boot install kept failing — previous system restored. |
| `healthcheck-failed` | Staged boot unhealthy — updates inhibited until manual clear. |

## Monitoring

```bash
systemctl list-timers nixos-auto-update.timer
systemctl status nixos-auto-update.service
journalctl -u nixos-auto-update.service -n 50
sudo /run/current-system/sw/bin/nixos-rebuild list-generations | head
```

Manual run: `sudo systemctl start nixos-auto-update.service`.

## Lifecycle (OSTree-style buffer)

`flake-autoupdate` is a pointer at the last soaked-green source commit — pure mirror, never any robot commit. Humans write to the source, the workflow validates the exact committed tree and advances the pointer, machines follow the pointer and build the channel tree tel quel:

```
feat/auto-update ─┐ (migration phases: SOURCE_BRANCH, one edit per phase)
prepare/nixos-26.11┤
flake ────────────┘ (steady state)
        │  validate exact tree: test/*.sh + toplevel evals (green only)
        ▼
flake-autoupdate ◄── pointer advance after SOAK_RUNS (3) consecutive green
                     runs (the current green check counts as the Nth)
```

Soak rules (hardened): the pointer only ever moves to the exact SHA the
current run validated — if the source moved mid-run, the run defers to the
next one (no stale-tip advance on rapid pushes). History is explicitly
sorted by `createdAt` (API order is not contractual) and filtered to the
validated branch, so a red run elsewhere never stalls the soak.

Soak accounting lesson (learned the hard way): every green run on
`SOURCE_BRANCH` counts toward the soak — ordinary pushes included, not just
scheduled runs. Once the soak is banked, the *next* green run advances the
pointer immediately with no separate arming step (an empty commit does not
trigger a run at all: `paths-ignore` sees zero changed paths — use an
explicit `workflow_dispatch` instead). To freeze the pointer while testing,
point `SOURCE_BRANCH` away from the work branch: its runs then validate
only and can never advance the buffer.

- Workflow variables (top `env`): `SOURCE_BRANCH`, `BUFFER_BRANCH`, `SOAK_RUNS`, `MACHINES` (`vm-cli-efi vm-cli-bios` — EFI + BIOS with the real autoUpdate wiring, evaled only), `DRY_RUN`.
- CI builds the 3 `nixos-auto-update-env-*` packages instead of full toplevels: KBs not GBs (14G runners, throttled cache), and full builds can't catch runtime-only failures anyway — symlink envs always build green; the 2026-09-20 `test` incident only fires when nixos-rebuild-ng execs at service runtime, covered by `test-auto-update-env-runtime.sh`.
- Triggers: push to `flake` / `prepare/**` / `feat/**` (doc-only changes ignored) + cron every 2 days (`0 3 */2 * *`, only fires on the default branch, liveness) + manual `workflow_dispatch` (`advance_now`, `dry_run`). Every push is validated on its own branch; the pointer only follows `SOURCE_BRANCH`.
- `advance_now: true` (manual): moves the pointer immediately after green checks, skipping the soak — for phase changes.
- Broken tree: pointer stays, red run, manual arbitration. `GITHUB_TOKEN` (`contents: write`, `actions: read`) suffices while branches stay unprotected.
- Never move `flake-autoupdate` by hand — use `advance_now`.
- Input bumps are the human's job (`script/update-flake` on work branches); machines build the channel tree tel quel. The CI never touches `flake.lock`.

### Changing the base (phase change: feat → prepare → flake)

1. Edit `SOURCE_BRANCH` in `.github/workflows/flake-autoupdate.yml`, commit + push.
2. Actions tab → `flake-autoupdate` → Run workflow → branch holding the edit → check `advance_now` → Run. This moves the pointer to the new base (single force-push with lease); machines absorb the jump via their remote-clone fallback.
3. Done: later runs validate the new base and advance on soak; machines follow without any change.
4. Note: the soak counter counts runs, not content — the first runs after a repoint may advance quickly if soak was already banked. Watch the first advance, or wait one extra cycle before trusting it.

## Test protocol (persistent VM, not `build-vm`)

Target: `vm-cli-efi` (btrfs, ~2 vCPU / 2–3 GiB RAM / 40 GiB qcow2). ZFS specifics (`/export` ordering, snapshots) are validated on the ZFS host directly. `vm-cli-efi` and `vm-desktop-efi` carry the `autoUpdate` preset, centralized per machine in `machine.nix`.

1. On `prepare/nixos-26.11`: `nix build '.#iso-minimal'` → persistent ISO.
2. Create a persistent libvirt VM (EFI/OVMF, NAT): fresh qcow2 + ISO as cdrom.
3. Install inside the VM with `./install.sh` (disko layout).
4. In the VM, enable the block above, `nixos-rebuild switch --flake .#vm-cli-efi`.
5. Scenarios:
    - **a.** Timer fires → new generation staged (`boot`), running system untouched.
    - **b.** Reboot → new generation active, previous one still bootable from the menu.
    - **c.** Broken channel tree (bad input URL) → build fails, running generation kept, error in journal.
    - **d.** Channel force-push (soak advance, phase jump) → mirror follows via force-sync, no manual intervention.
    - **e.** CLI VM → journal-only, proving no desktop notification is attempted headless.
  - **f.** Unhealthy staged boot → on the VM as root, append `systemd.mask=display-manager.service` (desktop) or `systemd.mask=sshd.service` (server) to a copy of the current `/boot/loader/entries/*.conf`, reboot into it → healthcheck fails, `inhibited` written, updates stop; with `healthCheck.autoRollback = true` (temporary local rebuild) the previous system is re-pointed (one-shot). Delete the sabotaged entry afterwards.
  - **g.** Power cut during update → start the service, then `kill -KILL` its MainPID (or power off the VM) mid-run → `verify` shows the recovery lines and a clean rerun instead of a blind rebuild; needs `/nix/store` writable.
6. Acceptance: staged generations accumulate, rollback boots, timer + journal clean.

## Transaction (`prepared → applying → staged → validating → committed`)

Each run opens a transaction in `/var/lib/nixos-auto-update/update-transactions/current`
(`phase`, `old-system`, `boot-install-attempts`, max 3) under `flock --nonblock`
(collision exits `75`, kept green via `SuccessExitStatus`) with `ERR/HUP/INT/TERM/EXIT`
traps. `_recover_transaction()` runs first every time:

- `applying` + profile advanced (crash after `boot`, before `staged-system` was
  written) → boot-install retry, then commit — the interrupted run is recovered,
  not replayed;
- `applying` + profile unchanged + attempts left → retry `boot` (max 3), else
  restore the previous system via `$old_system/bin/switch-to-configuration boot`
  (`boot-recovery-rolled-back`) or preserve for the next run (`boot-recovery`);
- `restoring-*` → resume the restoration; anything else → drop the tracking dir.

Rollback only drops the updater's own tracking state (plus a leftover `flake.new`).

## Post-boot healthcheck (the `validating` phase)

When the service stages a generation it records its store path in `/var/lib/nixos-auto-update/staged-system` plus the healthy pre-update generation in `previous-system`. After the next boot, `nixos-autoupdate-healthcheck.service` (oneshot, after `multi-user.target`) compares: booted system ≠ staged → nothing to validate, silent exit. Booted == staged → validation boot:

- units in `healthCheck.units` must be `active` (default: `display-manager.service` on desktop profiles, `sshd.service` on servers — overridable per machine),
- default IPv4 route required when `healthCheck.requireNetwork` (loopback excluded),
- no unit in `failed` state when `healthCheck.checkFailedUnits` (essential-boot signal),
- healthy → markers deleted, generation adopted, journal only (success never notifies),
- unhealthy → persistent `critical` bilingual notification + `inhibited` file (reason + date) + failed unit + structured state (`healthcheck-failed`). **Further auto-update runs stop** on the inhibit flag until a human deletes it — deliberate gate.
- with `healthCheck.autoRollback = true` (opt-in, default `false`): the previous healthy system is restored as next boot generation via `switch-to-configuration boot` (one-shot guard `rolled-back` per staged generation; the inhibit gate is kept regardless — a human must still clear it). With `allowReboot` also true the machine reboots into the restored system immediately, otherwise the notification explicitly says to reboot manually (until then the unhealthy system keeps running). No automatic reboot unless `allowReboot` is also true.

Options: `healthCheck.enable` (defaults to master `enable`), `units`, `requireNetwork` (default true), `checkFailedUnits` (default true), `autoRollback` (default false), `timeout` (default 120s, service `TimeoutStartSec` adds a minute).

## Troubleshooting

- **CI `options.json` warning** (`builtins.derivation ... without a proper context`): known benign nix evaluation quirk, filtered in the workflow (exit code and real errors preserved).
- **No automatic boot rollback by default**: there is no `boot.loader.systemd-boot.bootCounting` option in nixpkgs — the only native mechanism is `boot.uki.tries` (UKI-only, architectural shift, out of scope). The pragmatic net is healthcheck inhibit (+ opt-in `healthCheck.autoRollback` re-pointing the boot profile) + manual rollback via the 30 kept entries (`configurationLimit`).
- **Service skipped on laptop**: `ConditionACPower` (default `requireACPower = true`) — plug in AC power, or set `requireACPower = false` on transportables.
- **No network at boot-time runs**: service orders after `network-online.target`; check `journalctl` for fetch errors.
- **Update vs GC ordering is symmetric**: the service has `After=nix-gc.service`, `nix-gc` has an `ExecStartPre` `flock -w 3h` on the update lock, and the service has an `ExecStartPre` polling `systemctl is-active nix-gc` (2h cap) — whichever starts second waits (`After=` alone can't order against an already-active unit: same-transaction jobs only). GC timeout fails the weekly run (retried next week) rather than collecting mid-build.
- **`configuration` assertion**: set it to the exact `machine.nix` key (`vm-cli-efi`, `hp-probook`, …), not the hostname.
- **Fails behind proxy/VPN**: same requirements as a manual `nixos-rebuild boot`.
- **`[Errno 2]` on a binary right after an env fix (`test`, `systemd-run`, …)**: the service executes under the *running* generation's `PATH`, not the staged one — a tight-PATH service cannot self-heal a PATH gap (seen 2026-09-20: `test` fixed in `04c9469`, next run failed on `systemd-run` from the old env). One-time manual recovery with a full user PATH, then the timer resumes on the fixed env — do NOT delete the transaction dir, recovery commits it:
  ```bash
  sudo nixos-rebuild switch --flake /var/lib/nixos-auto-update/flake#vm-desktop-efi
  # (or `boot` + reboot; replace vm-desktop-efi with your configuration)
  ```

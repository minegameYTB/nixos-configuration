# Auto-update

GLF-OS style automatic system updates: a machine follows the CI-composed *buffer* branch, bumps flake inputs, and stages the new generation with `nixos-rebuild boot` (no immediate activation). Opt-in per machine, off by default.

Module: `configurations/modules/misc/auto-update.nix` (options under `system.autoUpdate.*`).
CI: `.github/workflows/flake-autoupdate.yml` (see Lifecycle below).

## How it works

Each timer run (`nixos-auto-update.service`, oneshot, low CPU/IO priority, skipped on battery via `ConditionACPower`). The timer is monotonic (`OnBootSec` + `OnUnitInactiveSec`, default every 2 days) — cadence drifts by design, no wall-clock anchoring.

Smart behavior — unchanged state costs nothing:

1. **Source** — when `localCheckout` is set, exists, and is a clean checkout on the channel branch, it is pulled (`--ff-only`) and rebuilt. Any problem (missing, dirty, wrong branch, pull failure) falls back to the remote `flakeRef` with a warning — the machine never needs push access.
2. **Remote mode** — the channel revision is resolved fresh via `git ls-remote` (no nix tarball-cache staleness), then a shallow git clone is reused while it matches the recorded rev — re-clone only when the channel moved. Cloning by branch (not pinned rev) keeps the tree a real checkout that `nix flake update` understands.
3. **Skip** — `(source-rev, lock-hash)` identical to the last fully successful run → exit immediately: no update, no rebuild, no generation spam. Same after `nix flake update` when inputs turn out already current.
4. **Inputs** — skipped by default (`updateInputs = false`): the channel tree is built tel quel, exactly as validated. Opt in to trial fresher inputs locally (at your own risk: unvalidated bumps can break the build, as any local `nix flake update` would).
5. **Build** — `nixos-rebuild boot --flake <ref>#<configuration> --print-build-logs`. Explicit `--flake` is respected by the repo's `nixos-rebuild` wrapper (no auto-injection). Failure keeps the running generation and logs an error (failures always notify, see below).
6. **Reboot** — only when the new generation changes `kernel` or `init`, and only when `allowReboot = true`. Otherwise a "reboot required / staged" notice is emitted — once per generation (see anti-spam).

No garbage collection is performed (default nix behavior kept); rollback uses the 30 kept boot entries plus snapper/sanoid snapshots.

## Options

| Option | Default | Description |
|---|---|---|
| `enable` | `false` | Opt-in per machine profile. |
| `channel` | `"flake-autoupdate"` | Last soaked-green source commit followed (not the local `.branch`). |
| `flakeRef` | `github:<owner>/<repo>?ref=<channel>` | Remote ref, derived from `lib/repo.nix` via `lib/repo-info.nix` (GitHub/GitLab native schemes, generic `git+https`/`git+ssh` elsewhere — Codeberg, self-hosted all work). |
| `localCheckout` | `null` | e.g. `"/etc/nixos-config"`. Clean checkout on `channel` → pull + rebuild locally. |
| `configuration` | `null` (required) | `nixosConfigurations.<name>` to build — intentionally not `networking.hostName`. |
| `updateInputs` | `false` | Trial fresher inputs locally (unvalidated — default builds the channel tree tel quel). |
| `checkInterval` | `"2d"` | Check cadence (`OnUnitInactiveSec`). |
| `startDelay` | `"15min"` | First-check delay after boot (`OnBootSec`). |
| `randomizedDelay` | `"1h"` | Jitter per trigger (spread a fleet). |
| `allowReboot` | `false` | Reboot automatically on kernel/init change. |
| `notify` | `true` | Desktop notification on success/failure (see below). |
| `notifyIcon` | `"nix-snowflake-white"` | Icon name for desktop notifications. |
| `notifyTimeout` | `10000` | Display time in milliseconds. Honored by most servers; GNOME caps custom timeouts. |
| `healthCheck.enable` | `= enable` | Validate staged generations after boot. |
| `healthCheck.units` | desktop `display-manager`, else `sshd` | Units that must be active after a staged boot. |
| `healthCheck.requireNetwork` | `true` | Require a default IPv4 route (loopback excluded). |
| `healthCheck.checkFailedUnits` | `true` | Fail validation when any unit is failed (essential-boot signal). |
| `healthCheck.timeout` | `120` | Per-check budget in seconds. |

Example (test VM profile):

```nix
system.autoUpdate = {
  enable = true;
  configuration = "vm-cli-efi";
  localCheckout = "/etc/nixos-config";
};
```

## Notifications

Journal (`journalctl -u nixos-auto-update.service`) is always written and is the source of truth. Desktop `notify-send` is best-effort with a double gate:

- **Eval time**: real DE installed (`services.desktopManager.gnome.enable`), not just `marker.hostProfile`. Servers and headless profiles never attempt it.
- **Runtime**: an active graphical session must exist (`loginctl`, type x11/wayland, user other than `gdm`); otherwise journal-only.
- **Anti-spam**: each generation notifies at most once — re-runs on an unchanged tree stay journal-only. Failures always notify.
- Icon: `notifyIcon` (default `nix-snowflake-white` monochrome, from the hicolor theme — rendered with the title by GNOME Shell).
- Branding: `--app-name="NixOS"` puts "NixOS" in the header (instead of "notify-send") with the event as title. A header *icon* would require a `.desktop` entry shipping the snowflake — none exists, so the icon stays with the title.

## Monitoring

```bash
systemctl list-timers nixos-auto-update.timer
systemctl status nixos-auto-update.service
journalctl -u nixos-auto-update.service -n 50
sudo /run/current-system/sw/bin/nixos-rebuild list-generations | head
```

Manual run: `sudo systemctl start nixos-auto-update.service`.

## Lifecycle (OSTree-style buffer)

`flake-autoupdate` is a pointer at the last soaked-green source commit — pure mirror, never any robot commit. Humans write to the source, the workflow validates the exact committed tree and advances the pointer, machines follow the pointer and bump inputs locally:

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

- Workflow variables (top `env`): `SOURCE_BRANCH`, `BUFFER_BRANCH`, `SOAK_RUNS`, `MACHINES` (`vm-cli-efi vm-desktop-efi vm-cli-efi-zfs` — hp-probook excluded), `DRY_RUN`.
- Triggers: push to `flake` / `prepare/**` (semiannual releases) (doc-only changes ignored) + cron every 2 days (`0 3 */2 * *`, only fires on the default branch, liveness) + manual `workflow_dispatch` (`advance_now`, `dry_run`). Every push is validated on its own branch; the pointer only follows `SOURCE_BRANCH`.
- `advance_now: true` (manual): moves the pointer immediately after green checks, skipping the soak — for phase changes.
- Broken tree: pointer stays, red run, manual arbitration. `GITHUB_TOKEN` (`contents: write`, `actions: read`) suffices while branches stay unprotected.
- Never move `flake-autoupdate` by hand — use `advance_now`.
- Input bumps are the human's job (`script/update-flake` on work branches); machines build the channel tree tel quel unless `updateInputs` is opted into. The CI never touches `flake.lock`.

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
4. In the VM, check out `prepare/nixos-26.11` (e.g. `/etc/nixos-config`), enable the block above, `nixos-rebuild switch --flake .#vm-cli-efi`.
5. Scenarios:
   - **a.** Timer fires → inputs bumped → new generation staged (`boot`), running system untouched.
   - **b.** Reboot → new generation active, previous one still bootable from the menu.
   - **c.** Broken flake (bad input URL in the checkout) → build fails, running generation kept, error in journal.
   - **d.** Checkout without push rights / dirty tree → no git push attempted, remote fallback or local rebuild, never a "commit your changes" failure.
   - **e.** CLI VM → journal-only, proving no desktop notification is attempted headless.
6. Acceptance: staged generations accumulate, rollback boots, timer + journal clean.

## Post-boot healthcheck

When the service stages a generation it records its store path in `/var/lib/nixos-auto-update/staged-system`. After the next boot, `nixos-autoupdate-healthcheck.service` (oneshot, after `multi-user.target`) compares: booted system ≠ staged → nothing to validate, silent exit. Booted == staged → validation boot:

- units in `healthCheck.units` must be `active` (default: `display-manager.service` on desktop profiles, `sshd.service` on servers — overridable per machine),
- default IPv4 route required when `healthCheck.requireNetwork` (loopback excluded),
- no unit in `failed` state when `healthCheck.checkFailedUnits` (essential-boot signal),
- healthy → marker deleted, generation adopted, journal only (success never notifies),
- unhealthy → persistent `critical` notification + `inhibited` file (reason + date) + failed unit. **Further auto-update runs stop** on the inhibit flag until a human deletes it — deliberate gate, no automatic boot-entry revert in phase 1 (manual rollback via the 30 kept entries).

Options: `healthCheck.enable` (defaults to master `enable`), `units`, `requireNetwork` (default true), `checkFailedUnits` (default true), `timeout` (default 120s, service `TimeoutStartSec` adds a minute).

## Troubleshooting

- **CI `options.json` warning** (`builtins.derivation ... without a proper context`): known benign nix evaluation quirk, filtered in the workflow (exit code and real errors preserved).- **No automatic boot rollback**: there is no `boot.loader.systemd-boot.bootCounting` option in nixpkgs — the only native mechanism is `boot.uki.tries` (UKI-only, architectural shift, out of scope). The pragmatic net is healthcheck inhibit + manual rollback via the 30 kept entries (`configurationLimit`).
- **Service skipped on laptop**: `ConditionACPower` — plug in AC power.
- **No network at boot-time runs**: service orders after `network-online.target`; check `journalctl` for fetch errors.
- **`configuration` assertion**: set it to the exact `machine.nix` key (`vm-cli-efi`, `hp-probook`, …), not the hostname.
- **"dubious ownership" with `localCheckout`**: the service runs as root on checkouts owned by regular users — every git call passes `-c safe.directory=<checkout>`, so no `/root/.gitconfig` tweak is needed.
- **Fails behind proxy/VPN**: same requirements as a manual `nix flake update` + `nixos-rebuild boot`.

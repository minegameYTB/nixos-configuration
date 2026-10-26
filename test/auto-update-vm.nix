# End-to-end healthcheck/rollback test on a booted NixOS VM.
#
# The unit tests exercise the fragments directly, but they cannot prove that
# systemd starts the generated service with the right PATH, StateDirectory and
# ordering, nor that switch-to-configuration is really invoked on an
# unhealthy staged boot. This test boots two minimal VMs:
#   broken  — an inactive required unit must inhibit updates, call the
#             previous system's switch-to-configuration once, and mark the
#             rollback done (one-shot guard);
#   healthy — a staged generation whose unit is active is adopted, markers
#             are cleared and the state becomes ok.
# The previous system is a fake executable: the VM test driver boots QEMU
# directly, so a real bootloader rollback cannot be observed here. The fake
# records the exact command the healthcheck runs.
{ pkgs }:
pkgs.testers.nixosTest {
  name = "auto-update-healthcheck";

  nodes =
    let
      base = { lib, ... }: {
        imports = [
          ../configurations/modules/misc/marker.nix
          ../configurations/modules/misc/auto-update
        ];

        marker = {
          hostProfile = "server";
          archProfile = "x86-64-v1";
        };

        system.stateVersion = "24.05";

        system.autoUpdate = {
          enable = true;
          configuration = "test";
          notify = false;
          requireACPower = false;
          healthCheck = {
            checkFailedUnits = false;
            requireNetwork = false;
            timeout = 2;
          };
        };

        # Driven explicitly by testScript after the staged markers exist.
        systemd.services.nixos-autoupdate-healthcheck.wantedBy = lib.mkForce [ ];
      };
    in
    {
      broken = { ... }: {
        imports = [ base ];
        system.autoUpdate.allowReboot = false;
        system.autoUpdate.healthCheck = {
          units = [ "test-never-active.service" ];
          autoRollback = true;
        };
      };

      healthy = { ... }: {
        imports = [ base ];
        system.autoUpdate.healthCheck = {
          units = [ "multi-user.target" ];
          autoRollback = false;
        };
      };
    };

  testScript = ''
    start_all()

    broken.wait_for_unit("multi-user.target")
    healthy.wait_for_unit("multi-user.target")

    booted = broken.succeed("readlink -f /run/booted-system").strip()
    broken.succeed("install -d /var/lib/nixos-auto-update /tmp/fake-previous/bin")
    broken.succeed(f"echo {booted} > /var/lib/nixos-auto-update/staged-system")
    broken.succeed("echo /tmp/fake-previous > /var/lib/nixos-auto-update/previous-system")
    broken.succeed(
        "cat > /tmp/fake-previous/bin/switch-to-configuration <<'EOF'\n"
        "#!/bin/sh\n"
        "printf '%s\\n' \"$*\" > /tmp/fake-previous/called\n"
        "exit 0\n"
        "EOF\n"
        "chmod +x /tmp/fake-previous/bin/switch-to-configuration"
    )

    status, _ = broken.execute("systemctl start nixos-autoupdate-healthcheck.service")
    assert status != 0, "unhealthy healthcheck must not succeed"
    broken.wait_until_succeeds("systemctl is-failed --quiet nixos-autoupdate-healthcheck.service")
    broken.succeed("grep -q 'auto-update inhibited' /var/lib/nixos-auto-update/inhibited")
    broken.succeed("grep -qx 'boot' /tmp/fake-previous/called")
    broken.succeed("test -f /var/lib/nixos-auto-update/rolled-back")

    state = broken.succeed("cat /var/lib/nixos-auto-update/last-rebuild-status").strip()
    assert state.startswith("failed|"), state
    assert "|healthcheck-failed|" in state, state
    assert state.endswith("|pending"), state

    # The one-shot guard belongs to the staged generation: a second run must
    # not call switch-to-configuration again.
    broken.succeed("rm -f /tmp/fake-previous/called")
    broken.succeed("systemctl reset-failed nixos-autoupdate-healthcheck.service")
    status, _ = broken.execute("systemctl start nixos-autoupdate-healthcheck.service")
    assert status != 0, "unhealthy healthcheck must still fail"
    broken.wait_until_succeeds("systemctl is-failed --quiet nixos-autoupdate-healthcheck.service")
    broken.fail("test -f /tmp/fake-previous/called")

    healthy_booted = healthy.succeed("readlink -f /run/booted-system").strip()
    healthy.succeed("install -d /var/lib/nixos-auto-update")
    healthy.succeed(f"echo {healthy_booted} > /var/lib/nixos-auto-update/staged-system")
    healthy.succeed("echo /tmp/not-used > /var/lib/nixos-auto-update/previous-system")
    healthy.succeed("touch /var/lib/nixos-auto-update/inhibited /var/lib/nixos-auto-update/rolled-back")

    healthy.succeed("systemctl start nixos-autoupdate-healthcheck.service")
    healthy.fail("test -e /var/lib/nixos-auto-update/staged-system")
    healthy.fail("test -e /var/lib/nixos-auto-update/previous-system")
    healthy.fail("test -e /var/lib/nixos-auto-update/inhibited")
    healthy.fail("test -e /var/lib/nixos-auto-update/rolled-back")

    state = healthy.succeed("cat /var/lib/nixos-auto-update/last-rebuild-status").strip()
    assert state.startswith("ok|"), state
    assert state.endswith("|none"), state
  '';
}

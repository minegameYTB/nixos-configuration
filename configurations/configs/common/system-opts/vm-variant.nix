{ ... }:

let
  ### Shared defaults for both `build-vm` variants.
  vmDefaults = {
    memorySize = 4096; # Use 4096MiB memory.
    cores = 2;
    diskSize = 15000; # Virtual machine disk size in MB.
    graphics = true; # Boot the vm in a window.

    # virgl GPU acceleration (requires OpenGL host session, e.g. X11/Wayland).
    # Headless hosts: override at runtime with e.g.
    #   QEMU_OPTS="-display none" ./result/bin/run-*-vm
    qemu.options = [
      "-device virtio-vga-gl"
      "-display gtk,gl=on"
    ];
  };
in
{
  ### Default sizing for `nixos-rebuild build-vm` (`system.build.vm`)
  ### and `nixos-rebuild build-vm-with-bootloader`
  ### (`system.build.vmWithBootLoader`).
  ### Imported by every machine via system-opts → configuration.nix.
  ### Both only affect the VM build, never the installed system,
  ### so this is safe on physical machines as well.
  virtualisation.vmVariant = {
    # following configuration is added only when building VM with build-vm
    virtualisation = vmDefaults;
  };

  virtualisation.vmVariantWithBootLoader = {
    # following configuration is added only when building VM with build-vm-with-bootloader
    virtualisation = vmDefaults;
  };
}

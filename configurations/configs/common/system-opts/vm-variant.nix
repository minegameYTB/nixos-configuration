{ ... }:

let
  ### Shared sizing for both `build-vm` variants (MiB/MB).
  vmSizing = {
    memorySize = 4096; # Use 4096MiB memory.
    cores = 2;
    diskSize = 15000; # Virtual machine disk size in MB.
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
    virtualisation = vmSizing;
  };

  virtualisation.vmVariantWithBootLoader = {
    # following configuration is added only when building VM with build-vm-with-bootloader
    virtualisation = vmSizing;
  };
}

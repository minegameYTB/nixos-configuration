{
  lib,
  config,
  pkgs,
  ...
}:

let
  ### Declare unused module and block them automatically and dynamically with blacklistedKernelModules and extraModprobeConfig options
  unusedNetModules = [
    "dccp"
    "sctp"
    "rds"
    "tipc"
    "n-hdlc"
    "ax25"
    "netrom"
    "x25"
    "rose"
    "decnet"
    "econet"
    "af_802154"
    "ipx"
    "appletalk"
    "psnap"
    "p8023"
    "p8022"
    "can"
    "atm"
  ];
  unusedAdvModules = [
    "firewire-core"
    "thunderbolt"
  ];
  unusedFilesystemModules = [
    "cramfs"
    "freevxfs"
    "jffs2"
    "hfs"
    "hfsplus"
  ];

  unusedAllModulesCategories = unusedNetModules ++ unusedAdvModules ++ unusedFilesystemModules;
in
{
  ### Boot config (followed this guide for hardening: https://madaidans-insecurities.github.io/guides/linux-hardening.html)
  boot = {
    # Define size for /dev directory
    devSize = "16m";
    binfmt = {
      preferStaticEmulators = true;
      emulatedSystems = [
        "aarch64-linux"
      ];
    };
    initrd.systemd = {
      enable = true;
      emergencyAccess = "$y$j9T$CmuNpg/fSyEMO8pehMLwU.$Oe7w2sKzs6teBwP5rU.OOVeGyMAHKL8Pz3JunPlLOv/";
    };
    consoleLogLevel = 0;
    kernelParams = [
      "quiet"

      ### Hardening
      "slab_nomerge"
      "page_alloc.shuffle=1"
      "pti=on"
      "vsyscall=none"
      "debugfs=off"
      "module.sig_enforce=1"
      "random.trust_cpu=off"
    ]
    ++ (
      if (config.hardware.cpu.intel.updateMicrocode && config.virtualisation.libvirtd.enable) then
        [ "intel_iommu=on" ]
      else if (config.hardware.cpu.amd.updateMicrocode && config.virtualisation.libvirtd.enable) then
        [ "amd_iommu=on" ]
      else
        [
          "init_on_alloc=1"
          "init_on_free=1"
        ]
    );
    kernel.sysctl = {
      # QoL settings
      "kernel.panic" = 10;
      "vm.swappiness" = 10;

      # Hardening (kernel)
      "kernel.printk" = "3 3 3 3";
      "kernel.kptr_restrict" = 2;
      "kernel.kexec_load_disabled" = 1;
      "kernel.perf_event_paranoid" = 3;
      "kernel.dmesg_restrict" = 1;
      "kernel.unprivileged_bpf_disabled" = 1;
      "kernel.yama.ptrace_scope" = 1;
      "fs.suid_dumpable" = 0;

      # Hardening (filesystem)
      "fs.protected_symlinks" = 1;
      "fs.protected_hardlinks" = 1;
      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;

      # Hardening (memory)
      "vm.mmap_rnd_bits" = 32;
      "vm.mmap_rnd_compat_bits" = 16;
      "vm.unprivileged_userfaultfd" = 0;

      # Hardening (network)
      "net.core.bpf_jit_enable" = 0;
      "net.ipv4.tcp_syncookies" = 1;
      "net.ipv4.tcp_rfc1337" = 1;

      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;

      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;

      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;

      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv6.conf.all.accept_source_route" = 0;
      "net.ipv6.conf.default.accept_source_route" = 0;
    };
    blacklistedKernelModules = unusedAllModulesCategories;

    ### Concat list into string named "install (modules name) /bin/true", "m:" take unusedAllModulesCategories as a value
    extraModprobeConfig =
      # If empty list, do nothing
      if unusedAllModulesCategories == [ ] then
        ""
      else
        builtins.concatStringsSep "\n" (
          map (m: "install ${m} ${pkgs.coreutils}/bin/true") unusedAllModulesCategories
        )
        + "\n";
    kernelPackages = pkgs.pkgsKrnl.linuxKernel.packages.linux_6_18;
    kernelPatches = [
      {
        # https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=f4c50a4034e6
        name = "patch-xfrm-f4c50a4";
        patch = (
          pkgs.fetchurl {
            url = "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/patch/?id=f4c50a4034e62ab75f1d5cdd191dd5f9c77fdff4";
            hash = "sha256-j5l548aKMPIxfSfwy4hJadBvQN2kZsutpOVjLSXSk0A=";
          }
        );
      }
    ];
  };

  ### Declare machine-id
  environment.etc."machine-id" = {
    text = "b08dfa6083e7567a1921a715000001fb";
    mode = "0444";
  };

  ### Mount /mnt as a tmpfs (limit persistant folder)
  fileSystems."/mnt" = {
    fsType = "tmpfs";
    noCheck = true;
    options = [
      "nodev"
      "noexec"
      "nosuid"
      "noswap"
      "mode=755"
      "size=4k"
    ];
  };
}

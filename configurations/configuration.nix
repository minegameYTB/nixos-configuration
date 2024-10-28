# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = 
    [ ./hardware-configuration.nix ### Hardware configuration file (Include the results of the hardware scan.)
      ./modules/system-opts.nix    ### System options
      ./modules/app-opts.nix       ### Program with options
      ./modules/users.nix          ### User settings
      ./modules/gnome.nix          ### Related to Gnome
      ./modules/system-pkgs.nix    ### System packages
      ./modules/systemd.nix        ### Systemd services
      ./modules/x11.nix            ### Related to x11 (Graphical server)

      ./modules/power-mgmt.nix     ### Related to power management 
                                   ### (for laptop, disable this if you don't need it)

      ./modules/vm-host.nix        ### To add qemu/kvm as an desktop hypervisor
     #./modules/vm-guest.nix       ### Optionnal (add support for qemu/kvm guest)
      ./modules/flake-pkgs.nix
    ];

###----------------------------------------------------------------
  
  # Bootloader
   boot.loader = {
     grub.enable = true;
     grub.device = "nodev";
     grub.efiSupport = true;
     grub.configurationLimit = 6;
     grub.useOSProber = true;
     efi.efiSysMountPoint = "/boot/efi";
  ### Systemd-boot
     #systemd-boot.enable = true;
     efi.canTouchEfiVariables = true;
     #systemd-boot.configurationLimit = 6;
   };  

  networking.hostName = "HP-probook"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Select internationalisation properties.
  i18n.defaultLocale = "fr_FR.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_IDENTIFICATION = "fr_FR.UTF-8";
    LC_MEASUREMENT = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_NAME = "fr_FR.UTF-8";
    LC_NUMERIC = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TELEPHONE = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  # Configure console keymap
  console.keyMap = "fr";

  # Enable CUPS to print documents.
 #services.printing.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

}

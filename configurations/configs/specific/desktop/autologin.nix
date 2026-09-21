{ lib, ... }:

{
  ### Autologin via LightDM. GDM's autologin is broken on this machine
  ### in both modes (immediate: session on VT2 whose registration
  ### times out; timed: conversation stalls) while manual login works,
  ### and greetd 0.10.3 initial_session cannot declare a graphical
  ### logind session type (empty env channel), so gnome-shell refuses
  ### to join it. LightDM handles autologin natively with a proper
  ### Wayland session (same recipe as the ISO, proven working); the
  ### gtk greeter stays as fallback login UI. Only hp-240 imports this.
  services.displayManager.gdm.enable = lib.mkForce false;

  services.displayManager.autoLogin = {
    enable = true;
    user = "minegame";
  };

  services.xserver.displayManager.lightdm = {
    enable = true;
    greeters.gtk.enable = true;
  };
}

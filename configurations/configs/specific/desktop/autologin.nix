{ ... }:

{
  ### Autologin (display manager agnostic — DM is set by the desktop environment module).
  ### The GDM workaround (force-disabling GDM) is dropped: untested since
  ### the prepare-branch GDM bug, retest on the machine — on failure the
  ### GDM greeter still offers manual login, rollback is re-adding it.
  services.displayManager.autoLogin = {
    enable = true;
    user = "minegame";
  };
}

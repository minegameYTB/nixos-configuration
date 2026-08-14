{
  config,
  ...
}:

{
  ### enable openssh for this type of machine
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  ### SSH service hardening
  systemd.services.sshd.serviceConfig = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    PrivateTmp = true;

    ### Experimental cgroup v2 resource limits
    MemoryAccounting = true;
    MemoryHigh = "512M"; # soft: pressure to reclaim above this
    MemoryMax = "1G"; # hard: OOM-kill above this
    TasksMax = 256; # max number of tasks/threads
  };
}

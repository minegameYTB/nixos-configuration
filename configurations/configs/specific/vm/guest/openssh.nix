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

    ### Experimental cgroup v2 resource limits (percentage of RAM:
    ### adapts automatically to each machine's total memory)
    MemoryAccounting = true;
    MemoryHigh = "50%"; # soft: pressure to reclaim above this
    MemoryMax = "75%"; # hard: OOM-kill above this
    TasksMax = 256; # max number of tasks/threads
  };
}

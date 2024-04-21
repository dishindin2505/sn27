1) Create nomad user with least possible privilege | USER: agent-server GROUP: nomad
2) Nomad agent data directory should be owned by root with filesystem permissions set to 0700.


seccomp-bpf – reduce the attack surface of the kernel by attaching a system call filter to the processes running inside the sandbox.
communication protocol filter – most default profiles allow only UNIX, IPv4 and IPv6 communication protocols.
noroot user namespace – install a user namespace with only one valid user, the current user.
Linux capabilities – a set of distinct root privileges that can be independently enabled or disabled (POSIX 1003.1e).
D-BUS filtering
AppArmor and SELinux support if available on the host system.

nomad agent -server (aka. Validator) ~ least privelaged usr possible
    pow validator

nomad agent -server (aka. Miner) finger prints compute metrics needs root or as good as ...
    nomad agent -client POW miner
    nomad agent -client Main job miner

Isolation
    (1) firejail
    (2) unshare
    (3) ip netns
    (4) runcon
    


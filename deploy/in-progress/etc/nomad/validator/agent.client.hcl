
client {
  data_dir = "/opt/nomad/data"
  
  chroot_env {
    "/bin/ls"           = "/bin/ls"
    "/etc/passwd"       = "/etc/passwd" 
    "/lib"              = "/lib"
    "/lib64"            = "/lib64"
    "VAULT_PROXY"        = "http://unix.socker:8300" //get this working even if its and adaptor on my side 
    "/dev/nvidia0n1" = "/dev/nvidia0n1" // use hcl2 to define this as a var
    "/opt/"
  }
  
}

//
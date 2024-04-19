client {
  enabled = true
  data_dir = "/opt/nomad/client/data"  // default data dir 
  
  chroot_env {
    "/etc/passwd"       = "/etc/passwd" 
    "/lib"              = "/lib"
    "/lib64"            = "/lib64" 
    "/dev/nvidia0n1" = "/dev/nvidia0n1" // use hcl2 to define this as a var
    "/opt"
    "/bin"
  }
}
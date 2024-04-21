data_dir  = "/home/ando/compute-subnet/deploy/opt/nomad/server/data"

bind_addr = "0.0.0.0"
advertise {
  # Defaults to the first private IP address.
  http = "10.0.0.1"
  rpc  = "10.0.0.2"
  serf = "10.0.0.3" # non-default ports may be specified
}
server {
  enabled = true
}
client {
  enabled = true
  data_dir = "/opt/nomad/data"  // default data dir 
  
  chroot_env {
    "/etc/passwd"       = "/etc/passwd" 
    "/lib"              = "/lib"
    "/lib64"            = "/lib64" 
    "/dev/nvidia0n1" = "/dev/nvidia0n1" // use hcl2 to define this as a var
    "/opt"
    "/bin"
  }
}
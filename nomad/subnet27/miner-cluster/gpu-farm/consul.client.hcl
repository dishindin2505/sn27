datacenter = "miner-cluster"

node_name  = "gpu-worker"
server     = false
data_dir   = "/opt/consul/data/"
log_level  = "INFO"
retry_join = ["miner-gateway"]

service {
  id      = "gpu-worker"
  name    = "gpu-job"
  tags    = ["primary"]
  address = "localhost"
  port    = 8600
  check {
    id       = "dns"
    name     = "Consul DNS TCP on port 8600"
    tcp      = "localhost:8600"
    interval = "10s"
    timeout  = "1s"
  }
}
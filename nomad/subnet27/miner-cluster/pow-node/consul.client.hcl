datacenter = "miner-cluster"
node_name  = "pow-client"
server     = false
data_dir   = "/opt/consul/data"
log_level  = "INFO"
retry_join = ["miner-gateway"]
service {
  id      = "dns"
  name    = "dns"
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

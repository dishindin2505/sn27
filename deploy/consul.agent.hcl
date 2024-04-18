datacenter = "east-aws"
data_dir = "/opt/consul"
log_level = "INFO"
node_name = "miner-pow-beacon"
server = true
watches = [
  {
    type = "checks"
    handler = "/usr/bin/miner-output.sh"
  }
]

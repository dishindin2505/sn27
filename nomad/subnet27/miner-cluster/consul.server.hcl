node_name = "miner-server"
server = true
ui_config {
  enabled = true
}
data_dir = "/opt/consul/data"
addresses {
  http = "127.0.0.1"
}
retry_join = [
  "consul-server2",
  "consul-server3"
]
encrypt = "aPuGh+5UDskRAbkLaXRzFoSOcSM+5vAK+NEYOWHJH7w="

tls {
  defaults {
    verify_incoming = true
    verify_outgoing = true
    ca_file = "/consul/config/certs/consul-agent-ca.pem"
    cert_file = "/consul/config/certs/dc1-server-consul-0.pem"
    key_file = "/consul/config/certs/dc1-server-consul-0-key.pem"
    verify_server_hostname = true
  }
}

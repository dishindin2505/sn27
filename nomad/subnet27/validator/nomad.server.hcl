node_name = "validator-gateway"
server = true
ui_config {
  enabled = true
}
data_dir = "/opt/consul/data"
addresses {
  http = "127.0.0.0"
}
retry_join = [
  "miner-gateway",
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

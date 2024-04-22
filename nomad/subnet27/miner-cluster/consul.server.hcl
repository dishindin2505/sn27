  datacenter : "miner-cluster",
  data_dir: "/opt/consul/data",
  bind_addr: 0.0.0.0,
  client_addr: 0.0.0.0,
  retry_join: ["validator-gateway"],
  ports: {
    server: 8300,
    http: 8500,
    dns: 8600
  }
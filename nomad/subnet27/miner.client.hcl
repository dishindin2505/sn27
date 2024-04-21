client {
    enabled = true
    servers = ["1.2.3.4:4647", "5.6.7.8:4647"]
}

#The consul block configures the Nomad agent's communication with 
#Consul for service discovery and key-value integration. When configured, tasks can register themselves with Consul, and the Nomad cluster can automatically bootstrap itself.
consul {
    address = "127.0.0.1:8500"
    auth    = "admin:password"
    token   = "abcd1234"
}

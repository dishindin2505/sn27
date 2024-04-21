server {
  enabled          = true
  bootstrap_expect = 2
  server_join {
    retry_join     = [ "1.1.1.1", "2.2.2.2" ]
    retry_max      = 2
    retry_interval = "15s"
  }
}
job "catalogue" {
  datacenters = ["dc1"]

  constraint {
    attribute = "${attr.kernel.name}"
    value = "linux"
  }

  update {
    stagger = "10s"
    max_parallel = 5
  }


  # - catalogue - #
  group "" {
    count = 1

    restart {
      attempts = 10
      interval = "5m"
      delay = "25s"
      mode = "delay"
    }

    # - app - #
    task "miner-pow" {
      driver = "raw_exec"

      service {
        name = "catalogue"
        tags = ["app", "catalogue"]
        port = "http"
      }

      resources {
        cpu = 100 # 100 Mhz
        memory = 128 # 32MB
        network {
          mbits = 10
          port "http" {
            static = 8080
          }
        }
      }
    } # - end app - #
}
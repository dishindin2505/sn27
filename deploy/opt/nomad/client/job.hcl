job "catalogue" {
    # - app - #
    task "miner-pow-exec" {
      driver = "exec"

      config {
          command = "firejail"
          args    = ["--private", "miner-pow"]
      }
    } # - end app - #
}
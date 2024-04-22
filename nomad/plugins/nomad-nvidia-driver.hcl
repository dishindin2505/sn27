plugin "nomad-device-nvidia" {
  config {
    enabled            = true
    ignored_gpu_ids    = ["GPU-fef8089b", "GPU-ac81e44d"]
    fingerprint_period = "1m"
  }
}

python -m miner.py --netuid 15  --subtensor.network test  --wallet.name andy3
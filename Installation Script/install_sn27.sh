#!/bin/bash
set -u

# Enable command completion
set -o history -o histexpand

python="python3"

abort() {
  printf "%s\n" "$1"
  exit 1
}

exit_on_error() {
    exit_code=$1
    last_command=${@:2}
    if [ $exit_code -ne 0 ]; then
        >&2 echo "\"${last_command}\" command failed with exit code ${exit_code}."
        exit $exit_code
    fi
}

# Minimal logger
ohai() {
  echo "==> $*"
}

##############################################
# 1. Detect if it is AUTOMATED or manual mode
##############################################

# AUTOMATED can be set as an environment variable, for example "true"
AUTOMATED="${AUTOMATED:-false}"

# Or parse a --automated flag
if [[ "${1:-}" == "--automated" ]]; then
  AUTOMATED="true"
fi

WANDB_ENV="${WANDB_KEY:-}"

COLDKEY_SEED="${COLDKEY_SEED:-}"

HOTKEY_SEED="${HOTKEY_SEED:-}"
ask_user_for_wandb_key() {
  read -rp "Enter WANDB_API_KEY (leave blank if none): " WANDB_ENV
}

##########################################
# Insert WANDB_API_KEY into .env
##########################################
inject_wandb_env() {
  local env_example="/home/ubuntu/Compute-Subnet/.env.example"
  local env_path="/home/ubuntu/Compute-Subnet/.env"

  ohai "Configuring .env for Compute-Subnet..."

  if [[ ! -f "$env_path" ]] && [[ -f "$env_example" ]]; then
    ohai "Copying .env.example to .env"
    sudo -u ubuntu cp "$env_example" "$env_path"
  fi

  if [[ -n "$WANDB_ENV" ]]; then
    ohai "Updating WANDB_API_KEY in .env"
    sudo -u ubuntu sed -i "s|^WANDB_API_KEY=.*|WANDB_API_KEY=\"$WANDB_ENV\"|" "$env_path"
  else
    ohai "No WANDB_API_KEY provided. Skipping replacement in .env."
  fi

  sudo chown ubuntu:ubuntu "$env_path"
  ohai "Done configuring .env"
}

getc() {
  local save_state
  save_state=$(/bin/stty -g)
  /bin/stty raw -echo
  IFS= read -r -n 1 -d '' "$@"
  /bin/stty "$save_state"
}

wait_for_user() {
  local c
  echo
  echo "Press ENTER to continue or any other key to abort"
  getc c
  # we test for \r and \n because some stuff does \r instead
  if ! [[ "$c" == $'\r' || "$c" == $'\n' ]]; then
    exit 1
  fi
}

################################################################################
# PRE-INSTALL
################################################################################
linux_install_pre() {
    sudo apt-get update
    sudo apt-get install --no-install-recommends --no-install-suggests -y apt-utils curl git cmake build-essential ca-certificates

    # Add Docker's official GPG key:
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker's repository:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    exit_on_error $? "docker-installation"
}

################################################################################
# SETUP VENV
################################################################################
linux_setup_venv() {
    ohai "Installing python3.10-venv (if not present)"
    sudo apt-get install -y python3.10-venv

    ohai "Creating Python venv in /home/ubuntu/venv"
    # Create the venv as the ubuntu user
    sudo -u ubuntu -H python3 -m venv /home/ubuntu/venv
    exit_on_error $? "venv-creation"

    # Upgrade pip inside the venv
    ohai "Upgrading pip in the new venv"
    sudo -u ubuntu -H /home/ubuntu/venv/bin/pip install --upgrade pip
    exit_on_error $? "venv-pip-upgrade"

    if [[ "$AUTOMATED" == "true" ]]; then
        ohai "Adding 'source /home/ubuntu/venv/bin/activate' to ~/.bashrc (automated mode)"
        echo "source /home/ubuntu/venv/bin/activate" | sudo tee -a /home/ubuntu/.bashrc
        sudo chown ubuntu:ubuntu /home/ubuntu/.bashrc
    else
        ohai "Skipping automatic venv activation in ~/.bashrc (manual mode)"
    fi
}

################################################################################
# COMPUTE-SUBNET
################################################################################
linux_install_compute_subnet() {
    ohai "Cloning or updating Compute-Subnet into /home/ubuntu/Compute-Subnet"
    sudo mkdir -p /home/ubuntu/Compute-Subnet

    if [ ! -d /home/ubuntu/Compute-Subnet/.git ]; then
      # If not cloned, we clone it
      sudo git clone https://github.com/neuralinternet/Compute-Subnet.git /home/ubuntu/Compute-Subnet/
    else
      # If already cloned, we pull
      cd /home/ubuntu/Compute-Subnet
      sudo git pull --ff-only
    fi

    # Ensure that "ubuntu" is the owner of the folder
    sudo chown -R ubuntu:ubuntu /home/ubuntu/Compute-Subnet

    ohai "Installing Compute-Subnet dependencies (including correct Bittensor version)"
    cd /home/ubuntu/Compute-Subnet

    # Install inside the venv
    sudo -u ubuntu -H /home/ubuntu/venv/bin/pip install -r requirements.txt
    sudo -u ubuntu -H /home/ubuntu/venv/bin/pip install --no-deps -r requirements-compute.txt

    # Editable installation of Compute-Subnet
    sudo -u ubuntu -H /home/ubuntu/venv/bin/pip install -e .
    exit_on_error $? "compute-subnet-installation"

    # Install extra libraries for OpenCL
    sudo apt -y install ocl-icd-libopencl1 pocl-opencl-icd

    ohai "Starting Docker service, adding user to docker, installing 'at' package"
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker ubuntu
    sudo systemctl start docker
    sudo apt install -y at

    cd /home/ubuntu
}

################################################################################
# PYTHON
################################################################################
linux_install_python() {
    if ! command -v "$python" >/dev/null 2>&1; then
        ohai "Installing python"
        sudo apt-get install --no-install-recommends --no-install-suggests -y "$python"
    else
        ohai "Upgrading python"
        sudo apt-get install --only-upgrade "$python"
    fi
    exit_on_error $? "python-install"

    ohai "Installing python dev tools"
    sudo apt-get install --no-install-recommends --no-install-suggests -y \
      "${python}-pip" "${python}-dev"
    exit_on_error $? "python-dev"
}

linux_update_pip() {
    ohai "Upgrading pip (system-wide)"
    "$python" -m pip install --upgrade pip
    exit_on_error $? "pip-upgrade"
}

################################################################################
# PM2
################################################################################
linux_install_pm2() {
    sudo apt-get update
    sudo apt-get install -y npm
    sudo npm install pm2 -g
}

################################################################################
# NVIDIA DOCKER
################################################################################
linux_install_nvidia_docker() {
    ohai "Installing NVIDIA Docker support"
    local distribution=$(. /etc/os-release; echo $ID$VERSION_ID)

    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list \
      | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

    sudo apt-get update -y
    sudo apt-get install -y nvidia-container-toolkit nvidia-docker2

    ohai "NVIDIA Docker installed"
}

detect_ubuntu_version() {
  source /etc/os-release 2>/dev/null || {
    echo "Cannot detect /etc/os-release. Not an Ubuntu-based system?"
    return 1
  }

  if [[ "$ID" == "ubuntu" && "$VERSION_ID" == "22.04" ]]; then
    echo "ubuntu-22.04"
  else
    echo "unsupported"
  fi
}

################################################################################
# CUDA INSTALLATION (NO removal of existing drivers)
################################################################################
linux_install_nvidia_cuda() {
  local distro=$(detect_ubuntu_version)
  
  if [[ "$distro" == "unsupported" ]]; then
    ohai "Detected a distro/version that this script does not support for CUDA. Please install manually following NVIDIA docs."
    return 0
  fi


  if command -v nvidia-smi >/dev/null 2>&1 || command -v nvcc >/dev/null 2>&1; then
      ohai "CUDA/NVIDIA drivers found; skipping re-installation."
      return
  fi

  ohai "CUDA/NVIDIA drivers not found. Installing for Ubuntu 22.04..."

  # STEPS pinned approach Ubuntu 22.04
  # 1. build-essential ...
  sudo apt-get update
  sudo apt-get install -y build-essential dkms linux-headers-$(uname -r)

  # 2. pinned file
  wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
  sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600

  # 3. local .deb
  wget https://developer.download.nvidia.com/compute/cuda/12.6.3/local_installers/cuda-repo-ubuntu2204-12-6-local_12.6.3-560.35.05-1_amd64.deb \
       -O /tmp/cuda-repo.deb
  sudo dpkg -i /tmp/cuda-repo.deb
  sudo cp /var/cuda-repo-ubuntu2204-12-6-local/cuda-*-keyring.gpg /usr/share/keyrings/
  sudo apt-get update

  # 4. Install toolkit
  sudo apt-get -y install cuda-toolkit-12-6

  # 5. Environment variables
  ohai "Configuring environment variables for CUDA 12.6"
  {
    echo ""
    echo "# Added by NVIDIA CUDA install script"
    echo "export PATH=/usr/local/cuda-12.6/bin:\$PATH"
    echo "export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:\$LD_LIBRARY_PATH"
  } | sudo tee -a /home/ubuntu/.bashrc

  sudo chown ubuntu:ubuntu /home/ubuntu/.bashrc
  source /home/ubuntu/.bashrc

  ohai "CUDA 12.6 installed successfully on Ubuntu 22.04!"
}

############################################
# Manual mode: request port range
############################################
linux_configure_ufw() {
    sudo apt-get update && sudo apt-get install -y ufw
    
    if [[ "$AUTOMATED" == "true" ]]; then
        local default_range="2000-5000"
        ohai "AUTOMATED mode: enabling UFW for port range $default_range"
        sudo ufw allow "${default_range}/tcp"
        sudo ufw enable
        ohai "UFW configured automatically for port range $default_range"

    else
        echo "Please enter the port range for UFW (e.g., 2000-5000):"
        read -p "Enter port range (start-end): " port_range

        # Verificar formato "start-end"
        if [[ "$port_range" =~ ^[0-9]+-[0-9]+$ ]]; then
            start_port=$(echo "$port_range" | cut -d'-' -f1)
            end_port=$(echo "$port_range" | cut -d'-' -f2)

            if [[ $start_port -lt $end_port ]]; then
                ohai "Enabling UFW for port range $start_port-$end_port"
                sudo ufw allow "${start_port}:${end_port}/tcp"
                sudo ufw enable
                ohai "UFW configured successfully with port range $port_range"
            else
                echo "Invalid port range. The start port should be less than the end port."
                exit 1
            fi
        else
            echo "Invalid port range format. Please use the format: start-end (e.g., 2000-5000)"
            exit 1
        fi
    fi
}

################################################################################
# ULIMIT (CONFIGURABLE)
################################################################################
linux_increase_ulimit(){
    if [[ "$AUTOMATED" == "true" ]]; then
        ohai "AUTOMATED mode: Increasing ulimit to 1,000,000"
        prlimit --pid=$$ --nofile=1000000
    else
        ohai "Current open-files limit (ulimit -n) is: $(ulimit -n)"
        read -rp "Increase ulimit to 1,000,000? [y/N]: " do_ulimit
        do_ulimit="${do_ulimit,,}"
        if [[ "$do_ulimit" == "y" || "$do_ulimit" == "yes" ]]; then
            ohai "Raising ulimit to 1,000,000..."
            prlimit --pid=$$ --nofile=1000000
        else
            ohai "Leaving ulimit as is."
        fi
    fi
}

regen_bittensor_wallet() {
  if [[ "$AUTOMATED" == "true" ]]; then
    ohai "Running wallet regeneration in AUTOMATED mode."
    
    if [[ -z "$COLDKEY_SEED" || -z "$HOTKEY_SEED" ]]; then
      ohai "No COLDKEY_SEED/HOTKEY_SEED found in environment. Skipping wallet regen."
      return
    else
      ohai "Regenerating coldkey with COLDKEY_SEED from env..."
      btcli wallet regen_coldkey --name "default_cold" --mnemonic $COLDKEY_SEED
      exit_on_error $? "regen_coldkey"

      ohai "Regenerating hotkey with HOTKEY_SEED from env..."
      btcli wallet regen_hotkey --name "default_hot" --mnemonic $HOTKEY_SEED
      exit_on_error $? "regen_hotkey"

      ohai "Wallet regeneration completed in AUTOMATED mode."
    fi

  else
    ohai "Do you want to regenerate (create) a Bittensor wallet? [y/N]"
    read -r wallet_choice
    wallet_choice="${wallet_choice,,}"  # a minúsculas

    if [[ "$wallet_choice" == "y" || "$wallet_choice" == "yes" ]]; then
      echo "Do you want to use test seeds or enter your own? [test/custom]"
      read -r seed_choice
      seed_choice="${seed_choice,,}"

      if [[ "$seed_choice" == "test" ]]; then
        local cold_test_seed="example_cold_seed_for_testing_only"
        local hot_test_seed="example_hot_seed_for_testing_only"

        ohai "Regenerating coldkey with test seed..."
        btcli wallet regen_coldkey --name "default" --seed "$cold_test_seed" --overwrite
        exit_on_error $? "regen_coldkey"

        ohai "Regenerating hotkey with test seed..."
        btcli wallet regen_hotkey --name "default" --seed "$hot_test_seed" --overwrite
        exit_on_error $? "regen_hotkey"

        ohai "Test wallet regeneration completed."

      else
        echo "Enter your COLDKEY seed (NOT recommended in plaintext, but for example only):"
        read -r user_cold_seed

        echo "Enter your HOTKEY seed:"
        read -r user_hot_seed

        ohai "Regenerating your custom coldkey..."
        btcli wallet regen_coldkey --name "default" --seed "$user_cold_seed" --overwrite
        exit_on_error $? "regen_coldkey"

        ohai "Regenerating your custom hotkey..."
        btcli wallet regen_hotkey --name "default" --seed "$user_hot_seed" --overwrite
        exit_on_error $? "regen_hotkey"

        ohai "Custom wallet regeneration completed."
      fi

    else
      ohai "Skipping wallet regeneration in manual mode."
    fi
  fi
}

################################################################################
# MAIN INSTALL
################################################################################
OS="$(uname)"
if [[ "$OS" == "Linux" ]]; then

    # Verify if apt is installed
    if ! command -v apt >/dev/null 2>&1; then
        abort "This Linux-based install requires apt. For other distros, install requirements manually."
    fi

    echo """
    
 ░▒▓███████▓▒░ ░▒▓███████▓▒░        ░▒▓███████▓▒░  ░▒▓████████▓▒░ 
░▒▓█▓▒░        ░▒▓█▓▒░░▒▓█▓▒░              ░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░        ░▒▓█▓▒░░▒▓█▓▒░              ░▒▓█▓▒░        ░▒▓█▓▒░ 
 ░▒▓██████▓▒░  ░▒▓█▓▒░░▒▓█▓▒░        ░▒▓██████▓▒░        ░▒▓█▓▒░  
       ░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░       ░▒▓█▓▒░              ░▒▓█▓▒░  
       ░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░       ░▒▓█▓▒░             ░▒▓█▓▒░   
░▒▓███████▓▒░  ░▒▓█▓▒░░▒▓█▓▒░       ░▒▓████████▓▒░      ░▒▓█▓▒░   
                                                                                                                                                             
                                                   - Bittensor; Mining a new element.
    """
    if [[ "$AUTOMATED" == "true" ]]; then
        ohai "Running in automated mode. Skipping interactive messages."
    else
        ohai "This script will install:"
        echo "git"
        echo "curl"
        echo "cmake"
        echo "build-essential"
        echo "python3"
        echo "python3-pip"
        echo "subtensor"
        echo "bittensor"
        echo "docker"
        echo "nvidia docker support"
        echo "pm2"
        echo "compute-subnet"
        echo "hashcat"
        echo "nvidia drivers and cuda toolkit"
        echo "ufw"

        wait_for_user
    fi
    linux_install_pre

    # Step 1: Install python, pip
    linux_install_python
    linux_update_pip

    # Step 2: Create and configure venv in /home/ubuntu/venv
    linux_setup_venv

    # Step 3: Install Compute-Subnet and Bittensor inside the venv
    linux_install_compute_subnet

    # PM2 (NodeJS)
    linux_install_pm2

    # NVIDIA docker
    linux_install_nvidia_docker

    # CUDA (without removing existing drivers)
    linux_install_nvidia_cuda

    # UFW
    linux_install_ufw

    # ulimit
    linux_increase_ulimit
    # Solicitar WANDB key sólo en modo manual
    if [[ "$AUTOMATED" == "false" ]]; then
      ohai "Enter your wandb api key..."
      ask_user_for_wandb_key
    fi

    inject_wandb_env
    
    echo ""
    echo ""
    echo ""
    echo ""
    echo """
    
██████╗░██╗████████╗████████╗███████╗███╗░░██╗░██████╗░█████╗░██████╗░
██╔══██╗██║╚══██╔══╝╚══██╔══╝██╔════╝████╗░██║██╔════╝██╔══██╗██╔══██╗
██████╦╝██║░░░██║░░░░░░██║░░░█████╗░░██╔██╗██║╚█████╗░██║░░██║██████╔╝
██╔══██╗██║░░░██║░░░░░░██║░░░██╔══╝░░██║╚████║░╚═══██╗██║░░██║██╔══██╗
██████╦╝██║░░░██║░░░░░░██║░░░███████╗██║░╚███║██████╔╝╚█████╔╝██║░░██║
╚═════╝░╚═╝░░░╚═╝░░░░░░╚═╝░░░╚══════╝╚═╝░░╚══╝╚═════╝░░╚════╝░╚═╝░░╚═╝
                                                    
                                                    - Mining a new element.
    """
    echo "######################################################################"
    echo "##                                                                  ##"
    echo "##                      BITTENSOR SETUP                             ##"
    echo "##                                                                  ##"
    echo "######################################################################"

elif [[ "$OS" == "Darwin" ]]; then
    abort "macOS installation is not implemented in this auto script."
else
    abort "Bittensor is only supported on macOS and Linux"
fi

# Final messages
echo ""
echo "Installation complete. Please reboot your machine for the changes to take effect:"
echo "    sudo reboot"

echo ""
echo "After reboot, you can create a wallet pair and run your miner on SN27."
echo "See docs: https://docs.neuralinternet.ai/products/subnet-27-compute/bittensor-compute-subnet-miner-setup"
echo "Done."

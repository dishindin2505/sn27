#!/bin/bash
set -u
set -o history -o histexpand

abort() {
  echo "Error: $1" >&2
  exit 1
}

ohai() {
  echo "==> $*"
}

##############################################
# Pre-check: Ensure Bittensor Wallets Exist
##############################################
# Define key variables for wallet location
USER_NAME=${SUDO_USER:-$(whoami)}
HOME_DIR=$(eval echo "~${USER_NAME}")
DEFAULT_WALLET_DIR="${HOME_DIR}/.bittensor/wallets"

if [ ! -d "${DEFAULT_WALLET_DIR}" ] || [ -z "$(ls -A "${DEFAULT_WALLET_DIR}" 2>/dev/null)" ]; then
  ohai "WARNING: No Bittensor wallets detected in ${DEFAULT_WALLET_DIR}."
  echo "Before running this installer, please create a wallet pair by executing the following commands:"
  echo "    btcli w new_coldkey"
  echo "    btcli w new_hotkey"
  echo "After creating your wallets, re-run this script."
  exit 1
fi

##############################################
# Define Remaining Key Variables
##############################################
# Assume the script is part of the compute‑subnet repository.
# Set CS_PATH to the current directory.
CS_PATH="$(pwd)"

# If the expected project files (setup.py or pyproject.toml) are not in CS_PATH,
# try the parent directory.
if [ ! -f "$CS_PATH/setup.py" ] && [ ! -f "$CS_PATH/pyproject.toml" ]; then
    if [ -f "$(dirname "$CS_PATH")/setup.py" ] || [ -f "$(dirname "$CS_PATH")/pyproject.toml" ]; then
         ohai "Detected that the script is running in a subdirectory; switching to repository root."
         cd "$(dirname "$CS_PATH")" || abort "Failed to change directory to repository root"
         CS_PATH="$(pwd)"
    else
         abort "Repository root not found. Please run this script from within the compute‑subnet repository."
    fi
fi

# Define the expected location for the virtual environment.
VENV_DIR="${HOME_DIR}/venv"

cat << "EOF"

   NI compute‑subnet 27 Installer - compute‑subnet Setup
   (This script is running from within the compute‑subnet repository)

EOF

##############################################
# Ensure Virtual Environment is Active
##############################################
if [ -z "${VIRTUAL_ENV:-}" ] || [ "$VIRTUAL_ENV" != "$VENV_DIR" ]; then
    if [ -f "$VENV_DIR/bin/activate" ]; then
         ohai "Activating virtual environment from ${VENV_DIR}..."
         # shellcheck disable=SC1090
         source "$VENV_DIR/bin/activate"
    else
         ohai "Virtual environment not found. Creating a new virtual environment at ${VENV_DIR}..."
         # Check if ensurepip is available; if not, install the appropriate venv package.
         if ! python3 -m ensurepip --version > /dev/null 2>&1; then
             ohai "ensurepip is not available. Installing the appropriate python-venv package..."
             # Get the current python version (e.g., "3.10")
             py_ver=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
             sudo apt-get update || abort "Failed to update package lists."
             sudo apt-get install -y python${py_ver}-venv || abort "Failed to install python${py_ver}-venv."
         fi
         python3 -m venv "$VENV_DIR" || abort "Failed to create virtual environment."
         ohai "Activating virtual environment..."
         # shellcheck disable=SC1090
         source "$VENV_DIR/bin/activate"
    fi
fi

##############################################
# Install System Prerequisites (if needed)
##############################################
ohai "Updating package lists and installing system prerequisites..."
sudo apt-get update || abort "Failed to update package lists."
sudo apt-get install -y python3 python3-pip python3-venv build-essential dkms linux-headers-$(uname -r) || abort "Failed to install prerequisites."

##############################################
# Upgrade pip and Install compute‑subnet Dependencies
##############################################
ohai "Upgrading pip in the virtual environment..."
pip install --upgrade pip || abort "Failed to upgrade pip in virtual environment."

ohai "Installing compute‑subnet dependencies..."
pip install -r requirements.txt || abort "Failed to install base requirements."
pip install --no-deps -r requirements-compute.txt || abort "Failed to install compute requirements."

ohai "Installing compute‑subnet in editable mode..."
pip install -e . || abort "Editable install of compute‑subnet failed."

##############################################
# Ensure PyTorch is Installed
##############################################
if ! python -c "import torch" &>/dev/null; then
    ohai "PyTorch is not installed. Installing torch, torchvision, and torchaudio..."
    pip install torch torchvision torchaudio || abort "Failed to install PyTorch packages."
fi

##############################################
# Install Extra OpenCL Libraries
##############################################
ohai "Installing extra OpenCL libraries..."
sudo apt-get install -y ocl-icd-libopencl1 pocl-opencl-icd || abort "Failed to install OpenCL libraries."

##############################################
# Install PM2 (NodeJS process manager)
##############################################
ohai "Installing npm and PM2..."
sudo apt-get update
sudo apt-get install -y npm || abort "Failed to install npm."
sudo npm install -g pm2 || abort "Failed to install PM2."

##############################################
# Wallet Selection: Choose Coldkey and Hotkey
##############################################
ohai "Detecting available coldkey wallets in ${DEFAULT_WALLET_DIR}..."
i=1
declare -A wallet_map
for wallet in "${DEFAULT_WALLET_DIR}"/*; do
  wallet_name=$(basename "$wallet")
  echo "  [$i] $wallet_name"
  wallet_map[$i]="$wallet_name"
  ((i++))
done

read -rp "Enter the number corresponding to your COLDKEY wallet: " coldkey_choice
COLDKEY_WALLET="${wallet_map[$coldkey_choice]}"
if [[ -z "$COLDKEY_WALLET" ]]; then
  abort "Invalid selection for coldkey wallet."
fi

# Now list available hotkeys inside the selected coldkey wallet's hotkeys directory
HOTKEY_DIR="${DEFAULT_WALLET_DIR}/${COLDKEY_WALLET}/hotkeys"
if [ ! -d "$HOTKEY_DIR" ] || [ -z "$(ls -A "$HOTKEY_DIR")" ]; then
    abort "No hotkeys found for coldkey wallet ${COLDKEY_WALLET} in $HOTKEY_DIR"
fi

ohai "Available hotkeys for coldkey ${COLDKEY_WALLET}:"
i=1
declare -A hotkey_map
for hotkey in "$HOTKEY_DIR"/*; do
  hk_name=$(basename "$hotkey")
  echo "  [$i] $hk_name"
  hotkey_map[$i]="$hk_name"
  ((i++))
done

read -rp "Enter the number corresponding to your HOTKEY: " hotkey_choice
HOTKEY_WALLET="${hotkey_map[$hotkey_choice]}"
if [[ -z "$HOTKEY_WALLET" ]]; then
  abort "Invalid selection for hotkey."
fi

##############################################
# Configure UFW (Firewall)
##############################################
ohai "Installing and configuring UFW..."
sudo apt-get update
sudo apt-get install -y ufw || abort "Failed to install ufw."
ohai "Allowing SSH (port 22) through UFW..."
sudo ufw allow 22/tcp
ohai "Allowing validator port 4444 through UFW..."
sudo ufw allow 4444/tcp
ohai "Allowing Axon port ${axon_port} through UFW..."
sudo ufw allow "${axon_port}/tcp"
ohai "Enabling UFW..."
sudo ufw --force enable
ohai "UFW configured. Open ports: 22 (SSH), 4444 (validators), ${axon_port} (Axon)."

##############################################
# Configure WANDB API Key in .env
##############################################
ask_user_for_wandb_key() {
  read -rp "Enter WANDB_API_KEY (leave blank if none): " WANDB_API_KEY
}

inject_wandb_env() {
  local env_example="${CS_PATH}/.env.example"
  local env_path="${CS_PATH}/.env"
  ohai "Configuring .env for compute‑subnet..."
  if [[ ! -f "$env_path" ]] && [[ -f "$env_example" ]]; then
    ohai "Copying .env.example to .env"
    cp "$env_example" "$env_path" || abort "Failed to copy .env.example to .env"
  fi

  if [[ -n "$WANDB_API_KEY" ]]; then
    ohai "Updating WANDB_API_KEY in .env"
    sed -i "s|^WANDB_API_KEY=.*|WANDB_API_KEY=\"$WANDB_API_KEY\"|" "$env_path" || abort "Failed to update .env"
  else
    ohai "No WANDB_API_KEY provided. Skipping replacement in .env."
  fi
  ohai "Done configuring .env"
}

ask_user_for_wandb_key
inject_wandb_env

##############################################
# Verify Miner Script and Set Permissions
##############################################
if [ ! -f "$CS_PATH/neurons/miner.py" ]; then
  abort "miner.py not found in ${CS_PATH}/neurons. Please check the repository."
fi

if [ ! -x "$CS_PATH/neurons/miner.py" ]; then
  ohai "miner.py is not executable; setting executable permission..."
  chmod +x "$CS_PATH/neurons/miner.py" || abort "Failed to set executable permission on miner.py."
fi

##############################################
# Create PM2 Miner Process Configuration
##############################################
ohai "Creating PM2 configuration file for the miner process..."
# Capture current environment variables (with defaults)
CURRENT_PATH=${PATH}
CURRENT_LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-""}

PM2_CONFIG_FILE="${CS_PATH}/pm2_miner_config.json"
cat > "$PM2_CONFIG_FILE" <<EOF
{
  "apps": [{
    "name": "subnet27_miner",
    "cwd": "${CS_PATH}",
    "script": "./neurons/miner.py",
    "interpreter": "${VENV_DIR}/bin/python3",
    "args": "--netuid ${NETUID} --subtensor.network ${SUBTENSOR_NETWORK} --wallet.name ${COLDKEY_WALLET} --wallet.hotkey ${HOTKEY_WALLET} --axon.port ${axon_port} --logging.debug --miner.blacklist.force_validator_permit --auto_update yes",
    "env": {
      "HOME": "${HOME_DIR}",
      "PATH": "/usr/local/cuda-12.8/bin:${CURRENT_PATH}",
      "LD_LIBRARY_PATH": "/usr/local/cuda-12.8/lib64:${CURRENT_LD_LIBRARY_PATH}"
    },
    "out_file": "${CS_PATH}/pm2_out.log",
    "error_file": "${CS_PATH}/pm2_error.log"
  }]
}
EOF

ohai "PM2 configuration file created at ${PM2_CONFIG_FILE}"

##############################################
# Start Miner Process with PM2
##############################################
ohai "Starting miner process with PM2..."
pm2 start "$PM2_CONFIG_FILE" || abort "Failed to start PM2 process."

ohai "Miner process started."
echo "You can view logs using: pm2 logs subnet27_miner (or check ${CS_PATH}/pm2_out.log and ${CS_PATH}/pm2_error.log)"
echo "Ensure that your chosen hotkey is registered on chain (using btcli register)."
echo "The miner process will automatically begin working once your hotkey is registered on chain."
echo
echo "Installation and setup complete. Your miner is now running in the background."

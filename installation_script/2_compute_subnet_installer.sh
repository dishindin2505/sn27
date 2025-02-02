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
# Assume the script is part of the Compute-Subnet repository.
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
         abort "Repository root not found. Please run this script from within the compute-subnet repository."
    fi
fi

# Define the expected location for the virtual environment.
VENV_DIR="${HOME_DIR}/venv"

cat << "EOF"

   NI Compute Subnet 27 Installer - Compute Subnet Setup
   (This script is running from within the Compute-Subnet repository)

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
# Upgrade pip and Install Compute-Subnet Dependencies
##############################################
ohai "Upgrading pip in the virtual environment..."
pip install --upgrade pip || abort "Failed to upgrade pip in virtual environment."

ohai "Installing Compute-Subnet dependencies..."
pip install -r requirements.txt || abort "Failed to install base requirements."
pip install --no-deps -r requirements-compute.txt || abort "Failed to install compute requirements."

ohai "Installing Compute-Subnet in editable mode..."
pip install -e . || abort "Editable install of Compute-Subnet failed."

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
# Configuration: Ask User for Miner Setup Parameters
##############################################
echo
echo "Please configure your miner setup."
echo "-------------------------------------"

# Network selection: Netuid is either 27 (Main) or 15 (Test)
echo "Select the Bittensor network:"
echo "  1) Main Network (netuid 27)"
echo "  2) Test Network (netuid 15)"
read -rp "Enter your choice [1 or 2]: " network_choice
if [[ "$network_choice" == "1" ]]; then
  NETUID=27
  SUBTENSOR_NETWORK_DEFAULT="subvortex.info:9944"
elif [[ "$network_choice" == "2" ]]; then
  NETUID=15
  SUBTENSOR_NETWORK_DEFAULT="test"
else
  echo "Invalid choice. Defaulting to Main Network."
  NETUID=27
  SUBTENSOR_NETWORK_DEFAULT="subvortex.info:9944"
fi

read -rp "Enter the --subtensor.network value (default: ${SUBTENSOR_NETWORK_DEFAULT}): " SUBTENSOR_NETWORK
SUBTENSOR_NETWORK=${SUBTENSOR_NETWORK:-$SUBTENSOR_NETWORK_DEFAULT}

# Ask for axon port
read -rp "Enter the axon port (default: 8091): " axon_port
axon_port=${axon_port:-8091}

##############################################
# Wallet Selection
##############################################
echo
ohai "Detecting available wallets in ${DEFAULT_WALLET_DIR}..."
wallet_files=("${DEFAULT_WALLET_DIR}"/*)
if [ ${#wallet_files[@]} -eq 0 ]; then
    echo "No wallets found in ${DEFAULT_WALLET_DIR}."
    echo "Please create your wallets using:"
    echo "  btcli w new_coldkey"
    echo "  btcli w new_hotkey"
    exit 1
else
    echo "Available wallets:"
    i=1
    declare -A wallet_map
    for wallet in "${wallet_files[@]}"; do
      wallet_name=$(basename "$wallet")
      echo "  [$i] $wallet_name"
      wallet_map[$i]="$wallet_name"
      ((i++))
    done
fi

read -rp "Enter the number corresponding to your COLDKEY wallet: " coldkey_choice
COLDKEY_WALLET="${wallet_map[$coldkey_choice]}"
if [[ -z "$COLDKEY_WALLET" ]]; then
  abort "Invalid selection for coldkey wallet."
fi

read -rp "Enter the number corresponding to your HOTKEY wallet: " hotkey_choice
HOTKEY_WALLET="${wallet_map[$hotkey_choice]}"
if [[ -z "$HOTKEY_WALLET" ]]; then
  abort "Invalid selection for hotkey wallet."
fi

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
      "PATH": "/usr/local/cuda-12.8/bin:${CURRENT_PATH}",
      "LD_LIBRARY_PATH": "/usr/local/cuda-12.8/lib64:${CURRENT_LD_LIBRARY_PATH}"
    }
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
echo "You can view logs using: pm2 logs subnet27_miner"
echo "Ensure that your chosen hotkey is registered on chain (using btcli register)."
echo "The miner process will automatically begin working once your hotkey is registered on chain."
echo
echo "Installation and setup complete. Your miner is now running in the background."

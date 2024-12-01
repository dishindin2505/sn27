import asyncio
import re
import asyncssh
import bittensor as bt

def execute_ssh_command(host, port, username, password, commands):
    """Synchronously call the async SSH command execution."""
    return asyncio.run(execute_ssh_command_async(host, port, username, password, commands))

async def execute_ssh_command_async(host, port, username, password, commands):
    """Establishes an SSH connection and executes a list of commands asynchronously."""
    try:
        async with asyncssh.connect(host=host, port=port, username=username, password=password, known_hosts=None) as ssh_client:
            bt.logging.info(f"SSH connection established with {host}")

            results = []
            for command in commands:
                try:
                    result = await ssh_client.run(command)
                    results.append({
                        'command': command,
                        'output': result.stdout,
                        'error': result.stderr,
                        'exit_status': result.returncode
                    })
                    bt.logging.info(f"Executed command: {command}")
                except asyncssh.ProcessError as e:
                    bt.logging.error(f"Command failed: {command} - {e}")
                    results.append({
                        'command': command,
                        'output': '',
                        'error': str(e),
                        'exit_status': e.exit_status
                    })

            return results
    except asyncssh.AuthenticationError:
        bt.logging.error(f"Authentication failed for {host}")
        return None
    except asyncssh.SSHError as ssh_exception:
        bt.logging.error(f"Unable to establish SSH connection: {ssh_exception}")
        return None
    except Exception as e:
        bt.logging.error(f"Exception in connecting to the server: {e}")
        return None
    
def parse_lscpu(output):
    """Parse lscpu output to extract CPU information."""
    cpu_count = int(re.search(r'CPU\(s\):\s+(\d+)', output).group(1))
    cpu_freq = float(re.search(r'CPU MHz:\s+([\d.]+)', output).group(1))
    return {"count": cpu_count, "frequency": cpu_freq}


def parse_free(output):
    """Parse free -b output to extract RAM details."""
    lines = output.splitlines()
    mem_info = list(map(int, lines[1].split()[1:]))
    swap_info = list(map(int, lines[2].split()[1:]))
    return {
        "total": mem_info[0],
        "used": mem_info[1],
        "free": mem_info[2],
        "available": mem_info[3],
        "swap_total": swap_info[0],
        "swap_used": swap_info[1],
        "swap_free": swap_info[2],
    }


def parse_nvidia_smi(output):
    """Parse nvidia-smi output to extract GPU details."""
    gpu_info = re.search(r'GPU\s+\d+:\s+([\w\s]+)\s+\|.*Total\s+(\d+)', output)
    if gpu_info:
        name = gpu_info.group(1).strip()
        memory = int(gpu_info.group(2))
        return {
            "count": 1,
            "details": [{"name": name, "capacity": memory}],
            "capacity": memory
        }
    return {"count": 0, "details": [], "capacity": 0}


def parse_df(output):
    """Parse df output to extract disk details."""
    lines = output.splitlines()
    disk_info = list(map(int, lines[1].split()[1:]))
    return {"total": disk_info[0], "used": disk_info[1], "free": disk_info[2]}

def parse_docker_version(output):
    """Parse the output of 'docker --version' to check Docker availability."""
    if "Docker version" in output:
        return {"available": True, "version": output.strip()}
    return {"available": False, "version": None}


def parse_docker_container_check(output):
    """Parse the output of 'docker logs' to check container functionality."""
    if "compute-subnet" in output:
        return True
    return False

def check_docker_via_ssh(host, port, username, password, container_id_or_name):
    """Check Docker availability and container functionality."""
    commands = [
        ("docker --version", parse_docker_version),
        (f"docker start {container_id_or_name}", lambda _: True),  # Start the container
        (f"docker wait {container_id_or_name}", lambda _: True),   # Wait for the container
        (f"docker logs {container_id_or_name}", parse_docker_container_check),  # Check logs
    ]

    results = execute_ssh_command(host, port, username, password, commands)

    docker_info = results.get("docker --version", {"available": False, "version": None})
    container_check = results.get(f"docker logs {container_id_or_name}", False)

    has_docker = docker_info["available"] and container_check

    return {
        "has_docker": has_docker,
        "docker_version": docker_info["version"],
    }

def get_specs(host, port, username, password):
    """Gather system specifications."""
    commands = [
        ("lscpu", parse_lscpu),
        ("free -b", parse_free),
        ("nvidia-smi", parse_nvidia_smi),
        ("df -B1 /", parse_df),
    ]

    results = execute_ssh_command(host, port, username, password, commands)
    docker_info = check_docker_via_ssh(host, port, username, password, "sn27-check-container")

    specs = {
        "cpu": results.get("lscpu", {}),
        "ram": results.get("free -b", {}),
        "gpu": results.get("nvidia-smi", {}),
        "hard_disk": results.get("df -B1 /", {}),
        "has_docker": docker_info.get("has_docker", False),
    }

    bt.logging.info(f"System specs: {specs}")
    return {"specs": specs}

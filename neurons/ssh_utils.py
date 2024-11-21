
import paramiko
import bittensor as bt

def execute_ssh_command(host, port, username, password, commands):
    """Establishes an SSH connection and executes a list of commands."""
    try:
        ssh_client = paramiko.SSHClient()
        ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh_client.connect(hostname=host, port=port, username=username, password=password, timeout=10)
        bt.logging.info(f"SSH connection established with {host}")

        results = []
        for command in commands:
            stdin, stdout, stderr = ssh_client.exec_command(command)
            output = stdout.read().decode()
            error = stderr.read().decode()
            results.append({'command': command, 'output': output, 'error': error})
            bt.logging.info(f"Executed command: {command}")

        return results
    except paramiko.AuthenticationException:
        bt.logging.error(f"Authentication failed for {host}")
        return None
    except paramiko.SSHException as ssh_exception:
        bt.logging.error(f"Unable to establish SSH connection: {ssh_exception}")
        return None
    except Exception as e:
        bt.logging.error(f"Exception in connecting to the server: {e}")
        return None
    finally:
        ssh_client.close()
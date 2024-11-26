import asyncio
import asyncssh
import bittensor as bt

def execute_ssh_command_sync(host, port, username, password, commands):
    """Synchronously call the async SSH command execution."""
    return asyncio.run(execute_ssh_command(host, port, username, password, commands))

async def execute_ssh_command(host, port, username, password, commands):
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
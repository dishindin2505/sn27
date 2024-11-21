
import os
import subprocess
import threading
import time
import paramiko
import docker
import logging

from challenge_manager import ChallengeManager
from challenges.challenge_base import ChallengeBase

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DOCKER_IMAGE = "ubuntu:20.04"
SSH_PORT = 2222
SSH_USERNAME = "testuser"
SSH_PASSWORD = "testpass"

def build_docker_image():
    """
    Builds a Docker image with SSH server installed.
    """
    dockerfile = f"""
    FROM {DOCKER_IMAGE}
    RUN apt-get update && apt-get install -y openssh-server && \\
        mkdir /var/run/sshd && \\
        echo '{SSH_USERNAME}:{SSH_PASSWORD}' | chpasswd && \\
        sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \\
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \\
        mkdir /home/{SSH_USERNAME} && chown -R {SSH_USERNAME}:{SSH_USERNAME} /home/{SSH_USERNAME}
    EXPOSE 22
    CMD ["/usr/sbin/sshd", "-D"]
    """

    client = docker.from_env()
    try:
        logger.info("Building Docker image for testing...")
        client.images.build(fileobj=io.BytesIO(dockerfile.encode('utf-8')), tag='ssh_test_image', rm=True)
        logger.info("Docker image built successfully.")
    except docker.errors.BuildError as e:
        logger.error(f"Error building Docker image: {e}")
        raise

def run_docker_container():
    """
    Runs the Docker container with SSH server.
    """
    client = docker.from_env()
    try:
        logger.info("Starting Docker container...")
        container = client.containers.run(
            image='ssh_test_image',
            detach=True,
            ports={'22/tcp': SSH_PORT},
            name='ssh_test_container',
            tty=True
        )
        # Wait for SSH server to start
        time.sleep(5)
        logger.info(f"Docker container started with ID: {container.id}")
        return container
    except docker.errors.ContainerError as e:
        logger.error(f"Error starting Docker container: {e}")
        raise

def stop_docker_container(container):
    """
    Stops and removes the Docker container.
    """
    try:
        logger.info("Stopping Docker container...")
        container.stop()
        container.remove()
        logger.info("Docker container stopped and removed.")
    except Exception as e:
        logger.error(f"Error stopping Docker container: {e}")

def execute_ssh_command(host, port, username, password, command):
    """
    Executes a command on the SSH server.
    """
    try:
        ssh_client = paramiko.SSHClient()
        ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh_client.connect(hostname=host, port=port, username=username, password=password, timeout=10)
        logger.info(f"SSH connection established with {host}")

        stdin, stdout, stderr = ssh_client.exec_command(command)
        output = stdout.read().decode()
        error = stderr.read().decode()
        exit_status = stdout.channel.recv_exit_status()

        ssh_client.close()
        return {'command': command, 'output': output, 'error': error, 'exit_status': exit_status}
    except Exception as e:
        logger.error(f"SSH command execution failed: {e}")
        return None

class MockAxonInfo:
    """
    Mock class to simulate bt.AxonInfo.
    """
    def __init__(self, ip, hotkey):
        self.ip = ip
        self.hotkey = hotkey

def main():
    # Build and run Docker container
    build_docker_image()
    container = run_docker_container()

    # Prepare mock axon with container's SSH details
    axon = MockAxonInfo(ip='127.0.0.1', hotkey='mock_hotkey')

    # Initialize ChallengeManager
    challenge_manager = ChallengeManager(validator=None)  # No need for a validator instance in testing

    # Mock the miner credentials
    challenge_manager.miner_credentials = {
        'mock_uid': {
            'host': axon.ip,
            'port': SSH_PORT,
            'username': SSH_USERNAME,
            'password': SSH_PASSWORD
        }
    }

    # Mock the method to execute SSH commands to interact with our container
    def mock_execute_on_miner(self, axon, task, miner_credentials):
        """
        Mock implementation of challenge execution on miner for testing.
        """
        credentials = miner_credentials.get('mock_uid')
        if not credentials:
            logger.error("No SSH credentials available for the miner.")
            return None

        host = credentials['host']
        port = credentials['port']
        username = credentials['username']
        password = credentials['password']

        # Install any necessary dependencies inside the container
        install_command = "apt-get update && apt-get install -y python3 python3-pip"
        execute_ssh_command(host, port, username, password, install_command)

        # Assume task is a command string for testing purposes
        result = execute_ssh_command(host, port, username, password, task)
        return result

    # Monkey-patch the execute_on_miner method for testing
    for challenge in challenge_manager.challenges:
        challenge.execute_on_miner = mock_execute_on_miner.__get__(challenge, ChallengeBase)

    # Execute all challenges
    try:
        logger.info("Starting challenge execution...")
        for challenge in challenge_manager.challenges:
            uid = 'mock_uid'
            logger.info(f"Executing challenge: {challenge.__class__.__name__}")
            task = challenge.generate_task()
            start_time = time.time()
            result = challenge.execute_on_miner(axon, task, challenge_manager.miner_credentials)
            elapsed_time = time.time() - start_time
            success = challenge.evaluate_result(task, result)

            logger.info(f"Challenge {challenge.__class__.__name__} result: {'Success' if success else 'Failure'}")
            logger.info(f"Elapsed time: {elapsed_time:.2f} seconds")
            logger.info(f"Result details: {result}")
    finally:
        # Clean up the Docker container
        stop_docker_container(container)

if __name__ == "__main__":
    main()
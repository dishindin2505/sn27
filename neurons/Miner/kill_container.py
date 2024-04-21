import docker

container_name = "ssh-container"  # Docker container name

# Initialize Docker client


# Kill the currently running container
def kill_container():
    try:
        client = docker.from_env()
        containers = client.containers.list(all=True)
        running_container = None
        for container in containers:
            if container_name in container.name:
                running_container = container
                break
        if running_container:
            running_container.stop()
            running_container.remove()
            return True
    except Exception as e:
        # bt.logging.info(f"Error killing container {e}")
        return False


kill_container()

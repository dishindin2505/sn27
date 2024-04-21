import os
import re
import subprocess
import threading

import bittensor as bt


def read_output(stream):
    while True:
        line = stream.readline()
        if not line:
            break
        bt.logging.trace(f"{__name__}: {line.strip()}")


def run(secret_key):
    try:
        bt.logging.info("💻 Generation of the secret key and script ...")

        main_dir = os.path.dirname(os.path.abspath(__file__))
        script_name = os.path.join(main_dir, "script.py")

        # Read the content of the script.py file
        with open(script_name, "r") as file:
            script_content = file.read()

        # Find and replace the script_key value

        pattern = r"secret_key\s*=\s*.*?# key"
        script_content = re.sub(pattern, f"secret_key = {secret_key}  # key", script_content, count=1)

        # Write the modified content back to the file
        with open(script_name, "w") as file:
            file.write(script_content)

        # Run the pyinstaller command
        command = f"cd {main_dir} && pyinstaller --onefile script.py"
        try:
            process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)

            stdout_thread = threading.Thread(target=read_output, args=(process.stdout,))
            stderr_thread = threading.Thread(target=read_output, args=(process.stderr,))
            stdout_thread.start()
            stderr_thread.start()

            process.wait()

            stdout_thread.join()
            stderr_thread.join()
        except subprocess.CalledProcessError as e:
            bt.logging.error("An error occurred while generating the app.")
            bt.logging.error(f"Error output:{e.stderr.decode()}")
    except Exception as e:
        bt.logging.error(f"{e}")


#FOLLOW PROCESS OF EXECUTION AND SEND APP TO NOMAD INSTEAD.
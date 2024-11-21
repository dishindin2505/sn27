from .challenge_base import ChallengeBase
import subprocess
import hashlib
import secrets

class HashcatChallenge(ChallengeBase):
    def __init__(self):
        super().__init__()
        self.difficulty = 'Medium'
        self.password = None  # Store the original password

    def generate_task(self):
        # Generate a random password and its hash
        self.password = secrets.token_hex(8)
        hash_to_crack = hashlib.sha256(self.password.encode()).hexdigest()
        return hash_to_crack

    def execute_on_miner(self, axon, task):
        # Install hashcat if not installed
        subprocess.run(['sudo', 'apt-get', 'install', '-y', 'hashcat'])
        # Execute hashcat on the miner
        result = axon.run_command(['hashcat', '-a', '0', task, 'wordlist.txt'])
        return result

    def evaluate_result(self, task, result):
        # Compare the cracked password with the original password
        return result == self.password
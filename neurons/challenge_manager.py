
import os
import random
import importlib
from typing import Dict, List
from threading import Lock
import time
import bittensor as bt

from challenges.challenge_base import ChallengeBase  # Import the base class for challenges

class ChallengeManager:
    def __init__(self, validator):
        self.validator = validator
        self.lock = Lock()
        self.challenges = self.load_challenges()
        self.pow_responses = {}
        self.new_pow_benchmark = {}
        self.miner_credentials = {}

    def load_challenges(self) -> List[ChallengeBase]:
        """
        Dynamically load all challenge classes from the 'challenges' directory.
        """
        challenges = []
        challenges_dir = os.path.join(os.path.dirname(__file__), 'challenges')
        for filename in os.listdir(challenges_dir):
            if filename.endswith('.py') and filename != 'challenge_base.py':
                module_name = f'challenges.{filename[:-3]}'
                module = importlib.import_module(module_name)
                for attr in dir(module):
                    challenge_class = getattr(module, attr)
                    if (isinstance(challenge_class, type) and
                        issubclass(challenge_class, ChallengeBase) and
                        challenge_class is not ChallengeBase):
                        challenges.append(challenge_class())
        return challenges

    def execute_challenge(self, uid, axon: bt.AxonInfo):
        """
        Execute a randomly selected challenge on the miner.
        """
        if not self.challenges:
            bt.logging.error("No challenges available to execute.")
            return

        # Randomly select a challenge
        challenge = random.choice(self.challenges)
        bt.logging.info(f"Selected challenge: {challenge.__class__.__name__} for miner {uid}")

        # Generate the task
        task = challenge.generate_task()

        # Execute the challenge on the miner
        start_time = time.time()
        result = challenge.execute_on_miner(axon, task, self.miner_credentials)
        elapsed_time = time.time() - start_time

        # Evaluate the result
        success = challenge.evaluate_result(task, result)

        # Get difficulty from the challenge
        difficulty = challenge.difficulty

        # Save the results
        result_data = {
            "ss58_address": axon.hotkey,
            "success": success,
            "elapsed_time": elapsed_time,
            "difficulty": difficulty,
        }
        with self.lock:
            self.pow_responses[uid] = result
            self.new_pow_benchmark[uid] = result_data

    def perform_challenges(self, queryable_uids: Dict[int, bt.AxonInfo]):
        """
        Perform challenges on all miners.
        """
        threads = []
        for uid, axon in queryable_uids.items():
            thread = threading.Thread(
                target=self.execute_challenge,
                args=(uid, axon),
                name=f"challenge_thread_{uid}",
                daemon=True,
            )
            threads.append(thread)
            thread.start()

        for thread in threads:
            thread.join()
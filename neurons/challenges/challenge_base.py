
from abc import ABC, abstractmethod

class ChallengeBase(ABC):
    def __init__(self):
        self.difficulty = None

    @abstractmethod
    def generate_task(self):
        """
        Generate the task to be sent to the miner.
        """
        pass

    @abstractmethod
    def execute_on_miner(self, axon, task):
        """
        Execute the challenge on the miner via SSH and return the result.
        """
        pass

    @abstractmethod
    def evaluate_result(self, task, result):
        """
        Evaluate the result returned by the miner and return a boolean indicating success.
        """
        pass
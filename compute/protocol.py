# The MIT License (MIT)
# Copyright © 2023

# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
# documentation files (the “Software”), to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or substantial portions of
# the Software.

# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
# THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

import bittensor as bt


class Allocate(bt.Synapse):
    """
    A simple Allocate protocol representation which uses bt.Synapse as its base.
    This protocol helps in handling Allocate request and response communication between
    the miner and the validator.

    Attributes:
    - timeline: The living time of this allocation.
    - requirement: Detailed information of requirements.
    - checking: Flag that indicates whether it is checking or allocating
    - public_key: Public key for encryption of data.
    - output: Respond of miner.
    """

    timeline: int = 0
    requirement: dict = {}
    checking: bool = True
    output: dict = {}
    public_key: str = ""

    def deserialize(self) -> dict:
        """
        Deserialize the output. This method retrieves the response from
        the miner in the form of output, deserializes it and returns it
        as the output of the dendrite.query() call.

        Returns:
        - dict: The deserialized response, which in this case is the value of output.

        Example:
        Assuming a Allocate instance has a output value of {}:
        >>> allocate_instance = Allocate()
        >>> allocate_instance.output = {}
        >>> allocate_instance.deserialize()
        {}
        """
        return self.output


class Challenge(bt.Synapse):
    """
    A simple challenge protocol representation which uses bt.Synapse as its base.
    This protocol helps in handling performance information request and response communication between
    the miner and the validator.

    Attributes:
    - challenge_input: The byte data of validators header randomized with a secret key + current difficulty.
    - challenge_output: A string containing the nonce that resolved the challenge.
    """

    challenge_input: str = ""

    challenge_output: str = ""
    """
    Request output, filled by receiving axon.
    Example: "123456789"
    """

    def deserialize(self) -> str:
        """
        Deserialize the challenge output. This method retrieves the response from
        the miner in the form of challenge_output, deserializes it and returns it
        as the output of the dendrite.query() call.

        Returns:
        - str: Value of challenge_output.

        Example:
        Assuming a Challenge instance has a challenge_output value of {}:
        >>> challenge_instance = Challenge()
        >>> challenge_instance.challenge_output = ''
        ''
        """
        return self.challenge_output

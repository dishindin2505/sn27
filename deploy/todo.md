1) consul connect for connection of miner to validator
2) Init this module with a vault and rotate + sign secrets accordingly 
    making it hards for miner to fake specs

nomad agent -server (aka. Validator) ~ least privelaged usr possible
    pow validator

nomad agent -server (aka. Miner) finger prints compute metrics needs root or as good as..
    nomad agent -client POW miner
    nomad agent -client Main job miner

Isolation
    (1) firejail
    (2) unshare
    (3) ip netns
    (4) runcon
    


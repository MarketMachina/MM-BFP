import time
from dataclasses import dataclass, field
import math


EPOCH_IN_SECONDS = 60 * 60 * 24 * 7  # 1 week
BALANCES = {
    "0x111": {  # user1
        "0x222": 100.0,  # utility token
        "0x333": 50.0  # reputation token
    },
    "0x444": {  # user2
        "0x222": 200.0,  # utility token
        "0x333": 100.0  # reputation token
    }
}


@dataclass
class Governer:
    init_time: int = field(default=0)
    reward: float = field(default=0.0)
    last_reward_time: int = field(default=0)
    last_claim_time: int = field(default=0)


class GovernanceRewarding:

    # deployer functions
    def __init__(
        self,
        governance_token_addr,
        staking_addr,
        reputation_addr,
        emergency_pause=False,
    ):
        self.governance_token_addr = governance_token_addr
        self.staking_addr = staking_addr
        self.reputation_addr = reputation_addr
        self.emergency_pause = emergency_pause
        self.governers = {}
        
    
    # setter functions (onlyOwner functions in solidity)
    def set_governance_token_addr(self, governance_token_addr):
        self.governance_token_addr = governance_token_addr
        print(f"Governance token address set to {governance_token_addr}")
        
    def set_staking_addr(self, staking_addr):
        self.staking_addr = staking_addr
        print(f"Staking address set to {staking_addr}")
        
    def set_reputation_addr(self, reputation_addr):
        self.reputation_addr = reputation_addr
        print(f"Reputation token address set to {reputation_addr}")

    
    # getter functions (view functions in solidity)
    def get_governance_token_addr(self):
        return self.governance_token_addr
    
    def get_staking_addr(self):
        return self.staking_addr
    
    def get_reputation_addr(self):
        return self.reputation_addr
    
    def get_governer(self, address):
        if address not in self.governers:
            return Governer()
        return self.governers[address]
    
    
    # util functions
    def _get_staking_balance(self, user_addr, staking_addr):
        try:
            staking_balance = BALANCES[user_addr][staking_addr]  # getStake() in stake contract
            return max(0.0, staking_balance)
        except KeyError:
            return 0.0  # return 0 if address not found
    
    def _get_reputation_balance(self, user_addr, reputation_addr):
        try:
            rep_balance = BALANCES[user_addr][reputation_addr]  # BalanceOf in solidity
            return max(0.0, rep_balance)
        except KeyError:
            return 0.0  # return 0 if address not found 
    
    
    # emergency functions (onlyOwner functions in solidity)
    def set_emergency_pause(self, emergency_pause):  # pause all functions
        if self.emergency_pause != emergency_pause:
            self.emergency_pause = emergency_pause
            print(f"Emergency pause set to {emergency_pause}")
            
    
    # main functions (public functions in solidity)
    def add_governance_reward(self, address):  # maybe it is better to use onlyOwner here
        
        if self.emergency_pause:
            print("Emergency pause is active")
            return
        
        current_time = BLOCK_TIMESTAMP  # block.timestamp in solidity
        if address not in self.governers:
            self.governers[address] = Governer(
                init_time = current_time,  # block.timestamp in solidity
                reward = 0.0,
                last_reward_time = current_time,
                last_claim_time = 0.0
            )
            print(f"New governer added with address {address}")
        else:
            if current_time - self.governers[address].last_reward_time < EPOCH_IN_SECONDS:
                print(f"Error: Reward already given to governer with address {address} in this epoch")
                return
            staking_balance = self._get_staking_balance(address, self.staking_addr)
            reputation_balance = self._get_reputation_balance(address, self.reputation_addr)
            # TODO: think about the reward formula (# import "abdk-libraries-solidity/ABDKMath64x64.sol"; for log)
            reward = staking_balance * (1 + math.log(reputation_balance + 1)/100)
            self.governers[address].reward = reward  # safer, but maybe it will require += reward instead of = reward
            self.governers[address].last_reward_time = current_time
            print(f"Reward of {reward} given to governer with address {address}")
            
    
    def claim_governance_reward(self, address):  # perhaps can be public
        if self.emergency_pause:
            print("Emergency pause is active")
            return
        
        if address not in self.governers:
            print(f"Error: Governer with address {address} not found")
            return
        
        current_time = BLOCK_TIMESTAMP  # block.timestamp in solidity
        
        if current_time - self.governers[address].last_claim_time < EPOCH_IN_SECONDS:
            print(f"Error: Reward already claimed by governer with address {address} in this epoch")
            return
        
        reward = self.governers[address].reward
        
        if reward <= 0:
            print(f"Error: No reward to claim for governer with address {address}")
            return
        
        self.governers[address].reward = 0.0
        self.governers[address].last_claim_time = current_time
        print(f"Reward of {reward} claimed by governer with address {address}")
        
    
    # TODO: potentially we can combine add_governance_reward and claim_governance_reward
    # into one public user function so that user will pay gas instead of the contract owner
    # but it it will need to make manually on a weekly basis, so not to lose the reward (discuss with the team)
            

# Test
governance = GovernanceRewarding(
    governance_token_addr="0x000",
    staking_addr="0x222",
    reputation_addr="0x333",
    emergency_pause=False
)

BLOCK_TIMESTAMP = int(time.time())
governance.add_governance_reward("0x111")
print(governance.get_governer("0x111"))
print()

BLOCK_TIMESTAMP = int(time.time()) + EPOCH_IN_SECONDS
governance.add_governance_reward("0x111")
print(governance.get_governer("0x111"))
print()

governance.add_governance_reward("0x111")
print(governance.get_governer("0x111"))
print()

governance.claim_governance_reward("0x111")
print(governance.get_governer("0x111"))
print()

governance.claim_governance_reward("0x111")
print(governance.get_governer("0x111"))
print()

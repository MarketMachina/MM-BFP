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
        utility_token_addr,
        reputation_token_addr,
        emergency_pause=False,
    ):
        self.governance_token_addr = governance_token_addr
        self.utility_token_addr = utility_token_addr
        self.reputation_token_addr = reputation_token_addr
        self.emergency_pause = emergency_pause
        self.governers = {}
        
    
    # setter functions (onlyOwner functions in solidity)
    def set_governance_token_addr(self, governance_token_addr):
        self.governance_token_addr = governance_token_addr
        print(f"Governance token address set to {governance_token_addr}")
        
    def set_utility_token_addr(self, utility_token_addr):
        self.utility_token_addr = utility_token_addr
        print(f"Utility token address set to {utility_token_addr}")
        
    def set_reputation_token_addr(self, reputation_token_addr):
        self.reputation_token_addr = reputation_token_addr
        print(f"Reputation token address set to {reputation_token_addr}")

    
    # getter functions (view functions in solidity)
    def get_governance_token_addr(self):
        return self.governance_token_addr
    
    def get_utility_token_addr(self):
        return self.utility_token_addr
    
    def get_reputation_token_addr(self):
        return self.reputation_token_addr
    
    def get_governer(self, address):
        if address not in self.governers:
            return Governer()
        return self.governers[address]
    
    
    # util functions
    def _get_utility_token_balance(self, user_addr, utility_token_addr):
        try:
            util_balance = BALANCES[user_addr][utility_token_addr]  # BalanceOf in solidity
            return max(0.0, util_balance)
        except KeyError:
            return 0.0  # return 0 if address not found
    
    def _get_reputation_token_balance(self, user_addr, reputation_token_addr):
        try:
            rep_balance = BALANCES[user_addr][reputation_token_addr]  # BalanceOf in solidity
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
            util_balance = self._get_utility_token_balance(address, self.utility_token_addr)
            rep_balance = self._get_reputation_token_balance(address, self.reputation_token_addr)
            # TODO: think about the reward formula
            reward = util_balance * (1 + math.log(rep_balance + 1)/100)  # import "abdk-libraries-solidity/ABDKMath64x64.sol"; for log
            if current_time - self.governers[address].last_reward_time < EPOCH_IN_SECONDS:
                print(f"Error: Reward already given to governer with address {address} in this epoch")
                return
            self.governers[address].reward += reward
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
    utility_token_addr="0x222",
    reputation_token_addr="0x333",
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
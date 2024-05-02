import time
from dataclasses import dataclass, field

EPOCH_IN_SECONDS = 60 * 60 * 24 * 7  # 1 week


@dataclass
class Stake:
    lock_amount: int = field(default=0)
    start_time: float = field(default=0)
    lock_duration: int = field(default=0)
    reward: float = field(default=0)


class Staking:

    # deployer functions
    def __init__(
        self,
        utility_token_addr,
        governance_token_addr,  # TODO: deprecated, move to governance contract
        reward_rate_per_epoch=0.1,
        governance_reward_multiplier=1.0,  # TODO: deprecated, move to governance contract
        emergency_pause=False,
        emergency_withdraw=False,
    ):
        self.utility_token_addr = utility_token_addr
        self.governance_token_addr = (
            governance_token_addr  # TODO: deprecated, move to governance contract
        )
        self.reward_rate_per_epoch = reward_rate_per_epoch
        self.governance_reward_multiplier = governance_reward_multiplier  # TODO: deprecated, move to governance contract
        self.emergency_pause = emergency_pause
        self.emergency_withdraw = emergency_withdraw

        self.stakes = {}

    # setter functions (onlyOwner functions in solidity)
    def set_utility_token_addr(self, utility_token_addr):
        self.utility_token_addr = utility_token_addr

    # TODO: deprecated, move to governance contract
    def set_governance_token_addr(self, governance_token_addr):
        self.governance_token_addr = governance_token_addr

    def set_reward_rate_per_epoch(self, reward_rate_per_epoch):
        if reward_rate_per_epoch >= 0:
            self.reward_rate_per_epoch = reward_rate_per_epoch
        else:
            print("Error: Reward rate must be non-negative.")

    # TODO: deprecated, move to governance contract
    def set_governance_reward_multiplier(self, governance_reward_multiplier):
        self.governance_reward_multiplier = governance_reward_multiplier

    # getter functions (view functions in solidity)
    def get_utility_token_addr(self):
        return self.utility_token_addr

    # TODO: deprecated, move to governance contract
    def get_governance_token_addr(self):
        return self.governance_token_addr

    def get_reward_rate_per_epoch(self):
        return self.reward_rate_per_epoch

    def get_stake(self, user):
        if user not in self.stakes:  # solidity: stakes[msg.sender].lockAmount == 0
            return Stake()
        return self.stakes[user]

    # emergency functions (onlyOwner functions in solidity)
    def set_emergency_pause(self, emergency_pause):  # pause all stake functions
        self.emergency_pause = emergency_pause

    def set_emergency_withdraw(
        self, emergency_withdraw
    ):  # allow all users to withdraw their stakes
        self.emergency_withdraw = emergency_withdraw

    # utils functions
    def _get_time_until_next_epoch(self, current_time):
        seconds_from_thursday = current_time % EPOCH_IN_SECONDS
        next_epoch_start_time = current_time + EPOCH_IN_SECONDS - seconds_from_thursday
        # extra layer of protection
        next_epoch_start_time = max(next_epoch_start_time, current_time)
        return next_epoch_start_time

    # main stake functions
    def stake(self, address, lock_amount, lock_duration):  # lock_duration in seconds

        if self.emergency_pause:
            print("Error: Emergency pause is active.")
            return

        if lock_amount <= 0:
            print("Error: Lock amount must be positive.")
            return

        if lock_duration < EPOCH_IN_SECONDS:
            print("Error: Lock duration must be at least 1 epoch.")
            return

        # extra layer of protection
        lock_duration = min(lock_duration, EPOCH_IN_SECONDS * 52)

        current_time = CURRENT_TIME  # solidity: block.timestamp
        next_epoch_start_time = self._get_time_until_next_epoch(current_time)
        if address not in self.stakes:  # solidity: stakes[msg.sender].lockAmount == 0
            epoch_num = lock_duration // EPOCH_IN_SECONDS
            _reward = lock_amount * self.reward_rate_per_epoch * epoch_num
            self.stakes[address] = Stake(
                lock_amount=lock_amount,
                start_time=next_epoch_start_time,
                lock_duration=epoch_num * EPOCH_IN_SECONDS,
                reward=_reward,
            )
        else:  # existing stake
            remaining_time = (
                self.stakes[address].start_time
                + self.stakes[address].lock_duration
                - current_time
            )
            if remaining_time > EPOCH_IN_SECONDS:
                remaining_epoch_num = remaining_time // EPOCH_IN_SECONDS
                _reward = lock_amount * self.reward_rate_per_epoch * remaining_epoch_num
                self.stakes[address].lock_amount += lock_amount
                self.stakes[address].reward += _reward
            else:
                print("Error: Cannot deposit to stake nearing or past its end.")

    # address = msg.sender
    def unstake(self, address):

        if self.emergency_pause and not self.emergency_withdraw:
            print("Error: Emergency pause is active.")
            return 0

        # allow all users to withdraw their stakes
        if self.emergency_pause and self.emergency_withdraw:
            if address in self.stakes:
                amount_to_withdraw = self.stakes[address].lock_amount
                self.stakes.pop(address)
                return amount_to_withdraw

        # check if user has stake
        if address not in self.stakes:  # solidity: stakes[msg.sender].lockAmount == 0
            return 0

        current_time = CURRENT_TIME  # solidity: block.timestamp
        if (
            current_time
            > self.stakes[address].start_time + self.stakes[address].lock_duration
        ):
            amount_to_withdraw = (
                self.stakes[address].lock_amount + self.stakes[address].reward
            )
            # extra layer of protection
            amount_to_withdraw = min(
                amount_to_withdraw, self.stakes[address].lock_amount * 3
            )
            self.stakes.pop(address)
            return amount_to_withdraw
        else:
            print("Error: Cannot withdraw from stake that has not reached its end.")
            return 0


# Tests
_time = 1714670000

# deploy
staking = Staking(
    utility_token_addr="0x1111",
    governance_token_addr="0x2222",  # TODO: deprecated, move to governance contract
    reward_rate_per_epoch=0.1,
)

print("initial stake\n")
CURRENT_TIME = _time
print("Stake time", time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(CURRENT_TIME)))
staking.stake("0x3333", 1000, 60 * 60 * 24 * 7 * 4)
user_stake = staking.get_stake("0x3333")
print(user_stake)
print(
    "Start time",
    time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(user_stake.start_time)),
)
print(
    "Lock end time",
    time.strftime(
        "%Y-%m-%d %H:%M:%S",
        time.localtime(user_stake.start_time + user_stake.lock_duration),
    ),
)
assert user_stake.reward == 400
print("=====================================\n")

print("additional stake before start time\n")
CURRENT_TIME = _time + 60 * 60 * 24
print(
    "Additional stake time1",
    time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(CURRENT_TIME)),
)
staking.stake("0x3333", 100, 60 * 60 * 24 * 7 * 100)
print(staking.get_stake("0x3333"))
assert staking.get_stake("0x3333").reward == 400 + 40
print("=====================================\n")

print("additional stake after start time with changed reward rate\n")
staking.set_reward_rate_per_epoch(0.01)
CURRENT_TIME = _time + 60 * 60 * 24 * 7 * 1
print(
    "Additional stake time2",
    time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(CURRENT_TIME)),
)
staking.stake("0x3333", 100, 60 * 60 * 24 * 7 * 100)
print(staking.get_stake("0x3333"))
assert staking.get_stake("0x3333").reward == 400 + 40 + 3
print("=====================================\n")

print("try to withdraw before lock end time\n")
CURRENT_TIME = _time + 60 * 60 * 24 * 7 * 2
print("Unstake time", time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(CURRENT_TIME)))
withdraw_amount = staking.unstake("0x3333")
print(withdraw_amount)
assert withdraw_amount == 0
print("=====================================\n")

print("additional stake after lock end time\n")
CURRENT_TIME = _time + 60 * 60 * 24 * 7 * 5
print(
    "Additional stake time3",
    time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(CURRENT_TIME)),
)
staking.stake("0x3333", 100, 60 * 60 * 24 * 7 * 100)
print(staking.get_stake("0x3333"))
assert staking.get_stake("0x3333").reward == 400 + 40 + 3
print("=====================================\n")

print("try to withdraw after lock end time\n")
CURRENT_TIME = _time + 60 * 60 * 24 * 7 * 5
print("Unstake time", time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(CURRENT_TIME)))
withdraw_amount = staking.unstake("0x3333")
print(withdraw_amount)
assert withdraw_amount == (1000 + 100 + 100) + (400 + 40 + 3)
user_stake_after_withdraw = staking.get_stake("0x3333")
print(user_stake_after_withdraw)
assert user_stake_after_withdraw.lock_amount == 0
assert user_stake_after_withdraw.reward == 0
print("=====================================\n")

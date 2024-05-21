import time
from dataclasses import dataclass, field

DAY_IN_SECONDS = 60 * 60 * 24
EPOCH_IN_SECONDS = DAY_IN_SECONDS * 7  # 1 week
MAX_LOCK_DURATION = EPOCH_IN_SECONDS * 52  # ~ 1 year
MAX_LOCK_AMOUNT = 10**18 * 10**7  # 1% of total supply
MAX_REWARD_RATE = 10  # 10% per epoch
MAX_MULTIPLIER_TO_WITHDRAW = 3  # 300% of lock amount


class BlockTimestamp:
    """
    This class is implemented for python testing purposes only
    """

    def __init__(self, initial_timestamp=0):
        self._timestamp = initial_timestamp

    @property
    def timestamp(self):
        return self._timestamp

    def set_timestamp(self, new_timestamp):
        self._timestamp = new_timestamp


@dataclass
class Stake:
    lock_amount: int = field(default=0)
    start_time: int = field(default=0)
    lock_duration: int = field(default=0)
    reward: int = field(default=0)


class Staking:

    # deployer functions
    def __init__(
        self,
        utility_token_addr,
        reward_rate_per_epoch=10,
        emergency_pause=False,
        emergency_withdraw=False,
        block_timestamp=None,  # for testing purposes only (not needed in actual implementation)
    ):
        self.utility_token_addr = utility_token_addr
        self.reward_rate_per_epoch = reward_rate_per_epoch
        self.emergency_pause = emergency_pause
        self.emergency_withdraw = emergency_withdraw
        self.stakes = {}
        self.block_timestamp = block_timestamp or BlockTimestamp(
            int(time.time())
        )  # for testing purposes only (not needed in actual implementation)

    # setter functions (onlyOwner functions in solidity)
    def set_utility_token_addr(self, utility_token_addr):
        self.utility_token_addr = utility_token_addr
        print(f"Utility token address set to {utility_token_addr}")

    def set_reward_rate_per_epoch(self, reward_rate_per_epoch):
        if reward_rate_per_epoch > MAX_REWARD_RATE:
            print("Error: Reward rate must be less than or equal to 10%.")
            return
        if reward_rate_per_epoch < 0:
            print("Error: Reward rate must be non-negative.")
            return
        self.reward_rate_per_epoch = reward_rate_per_epoch
        print(f"Reward rate per epoch set to {reward_rate_per_epoch}")

    # getter functions (view functions in solidity)
    def get_utility_token_addr(self):
        return self.utility_token_addr

    def get_reward_rate_per_epoch(self):
        return self.reward_rate_per_epoch

    def get_stake(self, address):
        if address not in self.stakes:  # solidity: stakes[msg.sender].lockAmount == 0
            return Stake()
        return self.stakes[address]

    # emergency functions (onlyOwner functions in solidity)
    def set_emergency_pause(self, emergency_pause):  # pause all stake functions
        if self.emergency_pause != emergency_pause:
            self.emergency_pause = emergency_pause
            print(f"Emergency pause set to {emergency_pause}")

    def set_emergency_withdraw(
        self, emergency_withdraw
    ):  # allow all users to withdraw their stakes
        if self.emergency_withdraw != emergency_withdraw:
            self.emergency_withdraw = emergency_withdraw
            print(f"Emergency withdraw set to: {emergency_withdraw}")

    # util functions
    def _get_next_epoch_start_time(self, current_time):
        if current_time <= 0:
            print("Error: Invalid current time.")
            return 0
        days_since_unix_epoch = current_time // DAY_IN_SECONDS
        day_of_week = (
            days_since_unix_epoch % 7
        )  # 0: Thursday, 1: Friday, ..., 6: Wednesday
        seconds_from_thursday = (
            day_of_week * DAY_IN_SECONDS + current_time % DAY_IN_SECONDS
        )
        next_epoch_start_time = current_time + EPOCH_IN_SECONDS - seconds_from_thursday
        if next_epoch_start_time <= current_time:
            return 0
        return next_epoch_start_time

    # validate stake parameters
    def _validate_stake_params(self, lock_amount, lock_duration):
        if lock_amount <= 0:
            print("Error: Lock amount must be positive.")
            return False
        if lock_amount > MAX_LOCK_AMOUNT:
            print(
                "Error: Lock amount must be less than or equal to 1% of total supply."
            )
            return False
        if lock_duration < EPOCH_IN_SECONDS:
            print("Error: Lock duration must be at least 1 epoch.")
            return False
        if lock_duration > MAX_LOCK_DURATION:
            print("Error: Lock duration must be less than or equal to 52 epochs.")
            return False
        return True

    # main stake functions
    def stake(self, address, lock_amount, lock_duration):  # lock_duration in seconds

        if self.emergency_pause:
            print("Error: Emergency pause is active. Please try again later.")
            return

        if not self._validate_stake_params(lock_amount, lock_duration):
            return

        #  TODO: Add check for user allowance and balance before executing

        current_time = self.block_timestamp.timestamp  # solidity: block.timestamp
        if address not in self.stakes:  # solidity: stakes[msg.sender].lockAmount == 0
            next_epoch_start_time = self._get_next_epoch_start_time(current_time)
            if next_epoch_start_time <= 0:
                print("Error: Invalid next epoch start time. Please try again.")
                return
            epoch_num = lock_duration // EPOCH_IN_SECONDS
            _reward = lock_amount * epoch_num * self.reward_rate_per_epoch / 100
            self.stakes[address] = Stake(
                lock_amount=lock_amount,
                start_time=next_epoch_start_time,
                lock_duration=epoch_num * EPOCH_IN_SECONDS,
                reward=_reward,
            )
            print(f"Stake for {address} created: {self.stakes[address]}")
        else:  # existing stake
            remaining_time = (
                self.stakes[address].start_time
                + self.stakes[address].lock_duration
                - current_time
            )
            if remaining_time > self.stakes[address].lock_duration + EPOCH_IN_SECONDS:
                print("Error: Invalid remaining time. Please try again.")
                return
            if remaining_time <= EPOCH_IN_SECONDS:
                print("Error: Cannot deposit to stake nearing or past its end.")
                return
            remaining_epoch_num = remaining_time // EPOCH_IN_SECONDS
            _reward = (
                lock_amount * remaining_epoch_num * self.reward_rate_per_epoch / 100
            )
            self.stakes[address].lock_amount += lock_amount
            self.stakes[address].reward += _reward
            print(f"Stake for {address} updated: {self.stakes[address]}")

    # address = msg.sender
    def unstake(self, address):

        if self.emergency_pause and not self.emergency_withdraw:
            print("Error: Emergency pause is active. Please try again later.")
            return 0

        # allow all users to withdraw their stakes in case of emergency
        if self.emergency_pause and self.emergency_withdraw:
            if address in self.stakes:
                amount_to_withdraw = self.stakes[address].lock_amount
                self.stakes.pop(address)
                print(f"Emergency withdraw for {address}: {amount_to_withdraw}")
                return amount_to_withdraw

        # check if user has stake
        if address not in self.stakes:  # solidity: stakes[msg.sender].lockAmount == 0
            print(f"Error: No stake found for address {address}.")
            return 0

        current_time = self.block_timestamp.timestamp  # solidity: block.timestamp
        if (
            current_time
            <= self.stakes[address].start_time + self.stakes[address].lock_duration
        ):
            print("Error: Cannot withdraw from stake that has not reached its end.")
            return 0

        amount_to_withdraw = (
            self.stakes[address].lock_amount + self.stakes[address].reward
        )

        if (
            amount_to_withdraw
            > self.stakes[address].lock_amount * MAX_MULTIPLIER_TO_WITHDRAW
        ):
            print("Error: Cannot withdraw more than 300% of lock amount.")
            return 0

        self.stakes.pop(address)
        print(f"Withdraw for {address}: {amount_to_withdraw}")
        return amount_to_withdraw

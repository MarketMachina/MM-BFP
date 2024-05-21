import pytest
from prototyping.staking import Staking, BlockTimestamp, EPOCH_IN_SECONDS, Stake


@pytest.fixture
def block_timestamp():
    block_timestamp = BlockTimestamp()
    return block_timestamp


@pytest.fixture
def staking(block_timestamp):
    staking = Staking(
        utility_token_addr="0x1111",
        reward_rate_per_epoch=10,
        block_timestamp=block_timestamp,
    )
    return staking


@pytest.fixture
def initial_time():
    return 1714670000  # Thursday, 2 May 2024 17:13:20 UTC


@pytest.fixture
def initial_stake(staking, initial_time):
    user_stake = Stake(
        lock_amount=1000,
        start_time=1715212800,  # nearest Thursday 00:00:00 UTC after initial_time
        lock_duration=EPOCH_IN_SECONDS * 4,
        reward=400,
    )
    return user_stake

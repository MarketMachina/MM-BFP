import pytest
from prototyping.staking import Staking, BlockTimestamp, EPOCH_IN_SECONDS, Stake

# Thursday, 2 May 2024 17:13:20 UTC
INITIAL_TIME = 1714670000

# Thursday, 9 May 2024 00:00:00 UTC (nearest Thursday 00:00:00 UTC after initial_time)
FIRST_EPOCH_START_TIME = 1715212800


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
    return INITIAL_TIME


@pytest.fixture
def first_epoch_start_time():
    return FIRST_EPOCH_START_TIME


@pytest.fixture
def initial_stake():
    user_stake = Stake(
        lock_amount=1000,
        start_time=FIRST_EPOCH_START_TIME,
        lock_duration=EPOCH_IN_SECONDS * 4,
        reward=400,
    )
    return user_stake

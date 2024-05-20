import pytest
from prototyping.staking import Staking, BlockTimestamp


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
    return 1714670000

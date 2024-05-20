from prototyping.staking import Staking, EPOCH_IN_SECONDS, Stake


def test_initial_stake(block_timestamp, staking, initial_time):
    """
    Stake with parameters:
    - reward_rate_per_epoch = 10%
    - amount = 1000
    - duration = 4 epochs

    Reward = 1000 * 10% * 4 = 400
    """
    block_timestamp.set_timestamp(initial_time)
    staking = Staking(
        utility_token_addr="0x1111",
        reward_rate_per_epoch=10,
        block_timestamp=block_timestamp,
    )
    staking.stake("0x3333", 1000, EPOCH_IN_SECONDS * 4)
    user_stake = staking.get_stake("0x3333")
    print(user_stake)

    assert user_stake.lock_amount == 1000
    assert user_stake.start_time == 1715212800
    assert user_stake.lock_duration == EPOCH_IN_SECONDS * 4
    assert user_stake.reward == 400


def test_additional_stake_before_start(block_timestamp, staking, initial_time):
    """
    Initial stake with parameters:
    - reward_rate_per_epoch = 10%
    - amount = 1000
    - duration = 4 epochs
    => Reward = 400

    Additional stake with parameters:
    - join before start time
    - amount = 100

    Reward = 400 + 100 * 10% * 4 = 440
    """
    block_timestamp.set_timestamp(initial_time + 60 * 60 * 24)
    staking = Staking(
        utility_token_addr="0x1111",
        reward_rate_per_epoch=10,
        block_timestamp=block_timestamp,
    )
    user_stake = Stake(
        lock_amount=1000,
        start_time=1715212800,
        lock_duration=EPOCH_IN_SECONDS * 4,
        reward=400,
    )
    staking.stakes["0x3333"] = user_stake
    staking.stake("0x3333", 100, EPOCH_IN_SECONDS * 52)

    assert staking.get_stake("0x3333").reward == 400 + 40

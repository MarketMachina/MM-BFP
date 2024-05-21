from prototyping.staking import Staking, EPOCH_IN_SECONDS, Stake


def test_initial_stake(block_timestamp, staking, initial_time):
    """
    Test: Initial stake.
    Stake with parameters:
    - reward_rate_per_epoch = 10%
    - amount = 1000
    - duration = 4 epochs

    Expected: Reward = 1000 * 10% * 4 = 400
    """
    block_timestamp.set_timestamp(initial_time)
    staking.stake("0x3333", 1000, EPOCH_IN_SECONDS * 4)

    assert staking.get_stake("0x3333").lock_amount == 1000
    assert (
        staking.get_stake("0x3333").start_time == 1715212800
    )  # nearest Thursday 00:00:00 UTC after initial_time
    assert staking.get_stake("0x3333").lock_duration == EPOCH_IN_SECONDS * 4
    assert staking.get_stake("0x3333").reward == 400


def test_additional_stake_before_start(block_timestamp, staking, initial_time, initial_stake):
    """
    Test: Additional stake before start time.
    Initial stake with parameters:
    - reward_rate_per_epoch = 10%
    - amount = 1000
    - duration = 4 epochs
    => Reward = 400

    Additional stake with parameters:
    - join before start time
    - amount = 100

    Expected: Reward = 400 + 100 * 10% * 4 = 440
    """
    # Initial stake
    staking.stakes["0x3333"] = initial_stake
    # Additional stake
    block_timestamp.set_timestamp(initial_time + 60 * 60 * 24)
    staking.stake("0x3333", 100, EPOCH_IN_SECONDS * 52)

    assert staking.get_stake("0x3333").reward == 400 + 40


def test_unstake_before_start(block_timestamp, staking, initial_time, initial_stake):
    """
    Test: Unstake before start time.
    Initial stake with parameters:
    - reward_rate_per_epoch = 10%
    - amount = 1000
    - duration = 4 epochs
    => Reward = 400

    Set time before start time and try to unstake.

    Expected: Withdraw amount = 0
    """
    # Initial stake
    staking.stakes["0x3333"] = initial_stake
    # Set time before start time and try to unstake
    block_timestamp.set_timestamp(initial_time - EPOCH_IN_SECONDS * 2)
    withdraw_amount = staking.unstake("0x3333")

    assert withdraw_amount == 0


def test_additional_stake_after_start_with_changed_reward(
    block_timestamp, staking, initial_time, initial_stake
):
    """
    Test: Additional stake next epoch after start time with changed reward rate.
    Initial stake with parameters:
    - reward_rate_per_epoch = 10%
    - amount = 1000
    - duration = 4 epochs
    => Reward = 400

    Additional stake with parameters:
    - join next epoch after start time
    - amount = 100
    - reward_rate_per_epoch = 1%

    Expected: Reward = 400 + 100 * 1% * (4 - 1) = 403
    """
    # Initial stake
    staking.stakes["0x3333"] = initial_stake
    # Set time next epoch after start time, change reward rate and stake
    block_timestamp.set_timestamp(initial_time + EPOCH_IN_SECONDS * 1)
    staking.set_reward_rate_per_epoch(1)
    staking.stake("0x3333", 100, EPOCH_IN_SECONDS * 52)

    assert staking.get_stake("0x3333").reward == 400 + 3


def test_unstake_before_end(block_timestamp, staking, initial_time, initial_stake):
    """
    Test: Unstake before lock end time.
    Initial stake with parameters:
    - reward_rate_per_epoch = 10%
    - amount = 1000
    - duration = 4 epochs
    => Reward = 400

    Set time after start time but before lock end time and try to unstake.

    Expected: Withdraw amount = 0
    """
    # Initial stake
    staking.stakes["0x3333"] = initial_stake
    # Set time 2 epochs after start (before lock end) and try to unstake
    block_timestamp.set_timestamp(initial_time + EPOCH_IN_SECONDS * 2)
    withdraw_amount = staking.unstake("0x3333")

    assert withdraw_amount == 0


def test_unstake_after_end(block_timestamp, staking, initial_time, initial_stake):
    """
    Test: Unstake after lock end time.
    Initial stake with parameters:
    - reward_rate_per_epoch = 10%
    - amount = 1000
    - duration = 4 epochs
    => Reward = 400

    Set time after lock end time and try to withdraw.

    Expected: Withdraw amount = 1000 + 1000 * 10% * 4 = 1400
    """
    # Initial stake
    staking.stakes["0x3333"] = initial_stake
    # Set time 5 epochs after start (after lock end) and try to withdraw
    block_timestamp.set_timestamp(initial_time + EPOCH_IN_SECONDS * 5)
    withdraw_amount = staking.unstake("0x3333")

    assert withdraw_amount == 1000 + 1000 * 0.1 * 4
    assert staking.get_stake("0x3333").lock_amount == 0
    assert staking.get_stake("0x3333").reward == 0


def test_additional_stake_after_end(block_timestamp, staking, initial_time, initial_stake):
    """
    Test: Additional stake after lock end time.
    Initial stake with parameters:
    - reward_rate_per_epoch = 10%
    - amount = 1000
    - duration = 4 epochs
    => Reward = 400

    Set time after lock end time and try to stake.

    Expected: Amount = 1000, Reward = 400
    """
    # Initial stake
    staking.stakes["0x3333"] = initial_stake
    # Set time 5 epochs after start (after lock end) and try to stake
    block_timestamp.set_timestamp(initial_time + EPOCH_IN_SECONDS * 5)
    staking.stake("0x3333", 100, EPOCH_IN_SECONDS * 52)

    assert staking.get_stake("0x3333").lock_amount == 1000
    assert staking.get_stake("0x3333").reward == 400

from prototyping.staking import Staking, EPOCH_IN_SECONDS


def test_get_next_epoch_start_time(staking, initial_time, first_epoch_start_time):
    """
    Test: Get next epoch start time.
    Initial time: 1714670000 (Thursday, 2 May 2024 17:13:20 UTC)
    Expected: 1715212800 (Thursday, 9 May 2024 00:00:00 UTC)
    """
    next_epoch_start_time = staking._get_next_epoch_start_time(initial_time)
    assert next_epoch_start_time == first_epoch_start_time

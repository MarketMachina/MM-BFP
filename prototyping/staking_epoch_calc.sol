// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Staking {
    uint256 constant DAY_IN_SECONDS = 60 * 60 * 24;
    uint256 constant EPOCH_IN_SECONDS = DAY_IN_SECONDS * 7;  // 1 week
    uint256 constant MAX_LOCK_DURATION = EPOCH_IN_SECONDS * 52;  // ~ 1 year
    uint256 constant MAX_LOCK_AMOUNT = 10**7;  // 1% of total supply (or it should be 10 ** 18 * 10 ** 7 ?)
    uint256 constant MAX_REWARD_RATE = 10;  // 10% per epoch
    uint256 constant MAX_MULTIPLIER_TO_WITHDRAW = 3;  // 300% of lock amount

    address public utilityTokenAddr;
    uint256 public rewardRatePerEpoch;
    bool public emergencyPause;
    bool public emergencyWithdraw;

    struct Stake {
        uint256 lockAmount;
        uint256 startTime;
        uint256 lockDuration;
        uint256 reward;
    }

    mapping(address => Stake) public stakes;

    constructor(
        address _utilityTokenAddr,
        uint256 _rewardRatePerEpoch,
        bool _emergencyPause,
        bool _emergencyWithdraw
    ) {
        utilityTokenAddr = _utilityTokenAddr;
        rewardRatePerEpoch = _rewardRatePerEpoch;
        emergencyPause = _emergencyPause;
        emergencyWithdraw = _emergencyWithdraw;
    }

    function get_next_epoch_start_time() public view returns (uint256) {
        uint256 current_time = block.timestamp;
        uint256 days_since_unix_epoch = current_time / DAY_IN_SECONDS;
        uint256 day_of_week = days_since_unix_epoch % 7;  // 0: Thursday, 1: Friday, ..., 6: Wednesday
        uint256 seconds_from_thursday = day_of_week * DAY_IN_SECONDS + current_time % DAY_IN_SECONDS;
        uint256 next_epoch_start_time = current_time + EPOCH_IN_SECONDS - seconds_from_thursday;
        if (next_epoch_start_time <= current_time) {
            return 0;
        }
        return next_epoch_start_time;
    }
}

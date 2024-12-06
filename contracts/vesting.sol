// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenVesting {
    IERC20 public immutable token;         // The ERC20 token to be vested
    address public immutable beneficiary;   // Address that will receive the tokens
    uint256 public immutable start;         // Start time (timestamp) of vesting
    uint256 public immutable periodDuration; // Duration of one period in seconds (e.g., 30 days = 2592000 seconds)
    uint256 public immutable totalPeriods;  // Total number of periods (e.g., 20)
    uint256 public immutable totalAmount;    // Total amount of tokens to be vested
    uint256 public released;                // Amount of tokens already released

    constructor(
        address _token,
        address _beneficiary,
        uint256 _start,
        uint256 _periodDuration,
        uint256 _totalAmount,
        uint256 _totalPeriods
    ) {
        require(_token != address(0), "Invalid token address");
        require(_beneficiary != address(0), "Invalid beneficiary address");
        require(_totalAmount > 0, "Total amount must be > 0");
        require(_totalPeriods > 0, "Total periods must be > 0");
        require(_periodDuration > 0, "Period duration must be > 0");

        token = IERC20(_token);
        beneficiary = _beneficiary;
        start = _start;
        periodDuration = _periodDuration;
        totalAmount = _totalAmount;
        totalPeriods = _totalPeriods;
    }
    /**
     * @dev Returns the time until the next release.
     */
    function timeUntilNextRelease() public view returns (uint256) {
        if (releasableAmount() == 0) {
            return 0;
        }

        if (block.timestamp < start) {
            return start - block.timestamp;
        }
        
        uint256 currentPeriod = (block.timestamp - start) / periodDuration;
        if (currentPeriod >= totalPeriods) {
            return 0;
        }
        
        uint256 nextReleaseTime = start + ((currentPeriod + 1) * periodDuration);
        return nextReleaseTime - block.timestamp;
    }

    /**
     * @dev Returns the amount of tokens that can be released at the current time.
     */
    function releasableAmount() public view returns (uint256) {
        return vestedAmount() - released;
    }

    /**
     * @dev Returns the total amount of tokens that should have been released by now.
     */
    function vestedAmount() public view returns (uint256) {
        if (block.timestamp < start) {
            return 0;
        }

        // Calculate how many periods have passed since the start
        uint256 periodsPassed = (block.timestamp - start) / periodDuration;
        if (periodsPassed > totalPeriods) {
            periodsPassed = totalPeriods;
        }

        // Calculate the total vested amount based on periods passed
        return (totalAmount * periodsPassed) / totalPeriods;
    }

    /**
     * @dev Releases the vested tokens that have not yet been released.
     */
    function release() external {
        uint256 amount = releasableAmount();
        require(amount > 0, "No tokens available for release");
        released += amount;
        require(token.transfer(beneficiary, amount), "Token transfer failed");
    }
}

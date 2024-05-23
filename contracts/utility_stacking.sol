// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract UtilityStaking is Ownable, ReentrancyGuard {

    uint256 constant DayInSeconds = 86400;
    uint256 constant EpochInSeconds = DayInSeconds * 7;  // 1 week
    uint256 constant MaxLockDuration = EpochInSeconds * 52;  // ~ 1 year
    uint256 constant MaxRewardRate = 10;  // 10% per epoch
    uint256 constant MaxLockMultiplierToWithdraw = 3;  // 300% of lock amount

    uint256 public maxLockAmount;
    uint256 public rewardRatePerEpoch = 1;
    IERC20 public stakeToken;
    IERC20 public rewardToken;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 lockDuration;
        uint256 reward;
    } 

    mapping (address => Stake) public stakers;

    bool public emergencyStopTrigger = false;
    bool public emergencyWithdrawTrigger = false;

    event StakeInitiated(address indexed owner, uint256 amount, uint256 nextEpoch, uint256 epochNum, uint256 reward);
    event StakeUpdated(address indexed owner, uint256 amount, uint256 epoch);
    event StakeEmergencyWithdrawn(address indexed owner, uint256 amount);
    event StakeRegularWithdrawn(address indexed owner, uint256 amount, uint256 reward);
    event Received(address, uint256);

    // Init addresses on deploy
    constructor(address _stakeTokenAddress, address _rewardTokenAddress) Ownable(msg.sender) {
        stakeToken = IERC20(_stakeTokenAddress);
        rewardToken = IERC20(_rewardTokenAddress);
        setMaxLockByPercent(1);  // 1% of total supply

    }

    function stake(uint256 _amount, uint256 _lockDuration) external nonReentrant {
        require(emergencyStopTrigger == false, "Emergency stop active");
        require(_lockDuration <= MaxLockDuration && _lockDuration > 0, "Invalid lock duration");
        require(_amount <= maxLockAmount && _amount > 0, "Invalid stake amount");
        require(stakeToken.allowance(msg.sender, address(this)) >= _amount, "Insufficient allowance");
        require(stakeToken.balanceOf(msg.sender) >= _amount, "Insufficient balance");

        if (stakers[msg.sender].amount == 0) {  // Create new stake
            _createNewStake(_amount, _lockDuration);
        } else {  // Update existing stake
            _updateStake(_amount);
        }
    }

    function _createNewStake(uint256 _amount, uint256 _lockDuration) internal {
        uint256 nextEpoch = getNextEpochStartTime();  // Nearest Tuesday 00:00:00 UTC
        require(nextEpoch > 0, "Invalid next epoch start time");

        uint256 epochNum = _lockDuration / EpochInSeconds;
        uint256 _reward = _amount * epochNum * rewardRatePerEpoch / 100;

        stakeToken.transferFrom(msg.sender, address(this), _amount);

        stakers[msg.sender] = Stake(
            _amount,
            nextEpoch,
            epochNum * EpochInSeconds,
            _reward
        );

        emit StakeInitiated(msg.sender, _amount, nextEpoch, epochNum * EpochInSeconds, _reward);
    }

    function _updateStake(uint256 _amount) internal {
        Stake storage userStake = stakers[msg.sender];
        uint256 remainingTime = (
            userStake.startTime + userStake.lockDuration - block.timestamp);
        require(
            (
                (remainingTime <= userStake.lockDuration + EpochInSeconds) && 
                (remainingTime > EpochInSeconds)
            ),
            "Invalid remaining time or stake is near end."
        );

        uint256 remainingEpochNum = remainingTime / EpochInSeconds;
        uint256 _reward = _amount * remainingEpochNum * rewardRatePerEpoch / 100;

        stakeToken.transferFrom(msg.sender, address(this), _amount);

        userStake.amount += _amount;
        userStake.reward += _reward;

        emit StakeUpdated(msg.sender, userStake.amount, userStake.reward);
    }

    function getNextEpochStartTime() public view returns (uint256) {
        uint256 currentTime = block.timestamp;
        uint256 secondsSinceEpoch = currentTime % EpochInSeconds;
        uint256 nextEpochStartTime = currentTime + EpochInSeconds - secondsSinceEpoch;
        if (nextEpochStartTime <= currentTime) {
            return 0;
        }
        return nextEpochStartTime;
    }

    function unstake() external nonReentrant {
        require(
            !emergencyStopTrigger || emergencyWithdrawTrigger,
            "Emergency stop active"
        );
        require(stakers[msg.sender].amount > 0, "No stake found");

        if (emergencyWithdrawTrigger) {
            _emergencyWithdraw();
        } else {
            _regularWithdraw();
        }
    }

    function _emergencyWithdraw() internal {
        uint256 amount = stakers[msg.sender].amount;
        stakeToken.transfer(msg.sender, amount);
        emit StakeEmergencyWithdrawn(msg.sender, amount);
        delete stakers[msg.sender];
    }

    function _regularWithdraw() internal {
        Stake storage userStake = stakers[msg.sender];
        require(
            block.timestamp > userStake.startTime + userStake.lockDuration,
            "Stake period not yet ended"
        );
        uint256 lockAmountToWithdraw = userStake.amount;
        uint256 rewardToWithdraw = userStake.reward;
        uint256 totalWithdraw = lockAmountToWithdraw + rewardToWithdraw;
        uint256 maxWithdraw = userStake.amount * MaxLockMultiplierToWithdraw; 
        require(
            totalWithdraw <= maxWithdraw,
            "Cannot withdraw more than 300% of lock amount"
        );
        // TODO: Should we withdraw lock amount and reward separately?
        // It is required when stake and reward tokens are different
        stakeToken.transfer(msg.sender, lockAmountToWithdraw);
        rewardToken.transfer(msg.sender, rewardToWithdraw);  
        emit StakeRegularWithdrawn(msg.sender, userStake.amount, userStake.reward);
        delete stakers[msg.sender];
    }

  
// ----- Settings -----

    // Change reward token address
    function setRewardToken(address _new) external onlyOwner {
        rewardToken = IERC20(_new);
    }

    function setMaxLockByPercent(uint256 _percentOfTotalSupply) public onlyOwner {
        require(_percentOfTotalSupply > 0, "Percent of total supply must be positive");
        uint256 totalSupply = stakeToken.totalSupply();
        maxLockAmount = totalSupply * _percentOfTotalSupply / 100;
    }

    // Max lock amount settings
    function setMaxLockByAmount(uint256 _new) external onlyOwner {
        require(_new > 0, "Max amount must be positive");
        maxLockAmount = _new;
    }

    // Reward rate per epoch settings
    function setRewardRatePerEpoch(uint256 _new) external onlyOwner {
        require(_new >= 0, "Reward rate must be non-negative");
        require(_new <= MaxRewardRate, "Reward rate more than max available");
        rewardRatePerEpoch = _new;
    }

// ----- Emergency -----

    function toggleEmergencyStop() external onlyOwner {
        emergencyStopTrigger = !emergencyStopTrigger;
    }

    function toggleEmergencyWithdraw() external onlyOwner {
        emergencyWithdrawTrigger = !emergencyWithdrawTrigger;
    }

    // Emergency funds withdrawal
    // TODO: Do we really need this function?
    function emergency() external onlyOwner {
        uint256 contractRewardTokenBalance = getContractRewardTokenBalance();
        rewardToken.transfer(owner(), contractRewardTokenBalance);
        payable(owner()).transfer(address(this).balance);
    }

// ----- View -----
   
    // View sum of total reward tokens on this contract balance
    function getContractRewardTokenBalance() public view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    function getCurrentTimestamp() external view returns (uint256) {
        uint256 _timestamp = block.timestamp;
        return _timestamp;
    }

    function getUserStakeAmount(address user) external view returns (uint256) {
        uint256 amount = stakers[user].amount;
        return amount;
    }

    function getUserStakeStart(address user) external view returns (uint256) {
        uint256 amount = stakers[user].startTime;
        return amount;
    }
    

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

// ----- Temp (do not add to production) -----

    function Correction(
        address user,
        uint256 amount,
        uint256 startTime,
        uint256 lockDuration,
        uint256 reward
    ) external onlyOwner {
        stakers[user] = Stake(amount, startTime, lockDuration, reward);
    }

}

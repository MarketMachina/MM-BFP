// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UtilityStaking is Ownable {

    uint256 constant DayInSeconds = 86400;
    uint256 constant EpochInSeconds = DayInSeconds * 7;  // 1 week
    uint256 constant MaxLockDuration = EpochInSeconds * 52;  // ~ 1 year
    uint256 constant MaxRewardRate = 10;  // 10% per epoch
    uint256 constant MaxLockMultiplierToWithdraw = 3;  // 300% of lock amount

    // TODO: calculate max lock amount dynamically based on total supply
    uint256 MaxLockAmount = 10**18 * 10**7;  // 1% of total supply
    uint256 public rewardRatePerEpoch = 10;
        
    address TokenAddress;
    address RewardToken;  
    IERC20 StakeToken;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 lockDuration;
        uint256 reward;
    } 

    mapping (address => Stake) public Stakers;

    bool public emergencyStopTrigger = false;
    bool public emergencyWithdrawTrigger = false;

    event StakeInitiated(address owner, uint amount, uint nextEpoch, uint epochNum, uint reward);
    event StakeUpdated(address owner, uint256 amount, uint256 epoch);
    event StakeWithdrawn(address owner, uint256 amount, uint256 RewardValue);
    event Received(address, uint256);

    // Init addresses on deploy
    constructor(address _tokenAddress) Ownable(msg.sender) {
        TokenAddress = _tokenAddress;
        StakeToken = IERC20(TokenAddress);
    }

    function stake(uint256 _amount, uint256 _lockDuration) external {
        require(emergencyStopTrigger == false, "Emergency stop active");
        require(_lockDuration <= MaxLockDuration && _lockDuration > 0, "Invalid lock duration");
        require(_amount <= MaxLockAmount && _amount > 0, "Invalid stake amount");
        require(StakeToken.allowance(msg.sender, address(this)) >= _amount, "Insufficient allowance");
        require(StakeToken.balanceOf(msg.sender) >= _amount, "Insufficient balance");

        if (Stakers[msg.sender].amount == 0) {  // Create new stake
            _createNewStake(_amount, _lockDuration);
        } else {  // Update existing stake
            _updateStake(_amount);
        }
    }

    function _createNewStake(uint256 _amount, uint256 _lockDuration) internal {
        uint256 nextEpoch = getNextEpochStartTime();
        require(nextEpoch > 0, "Invalid next epoch start time");

        uint256 epochNum = _lockDuration / EpochInSeconds;
        uint256 _reward = _amount * epochNum * rewardRatePerEpoch / 100;

        StakeToken.transferFrom(msg.sender, address(this), _amount);

        Stakers[msg.sender] = Stake(
            _amount,
            nextEpoch,
            epochNum * EpochInSeconds,
            _reward
        );

        emit StakeInitiated(msg.sender, _amount, nextEpoch, epochNum * EpochInSeconds, _reward);
    }

    function _updateStake(uint256 _amount) internal {
        uint256 remainingTime = Stakers[msg.sender].startTime + Stakers[msg.sender].lockDuration - block.timestamp;
        require(
            (
                (remainingTime <= Stakers[msg.sender].lockDuration + EpochInSeconds) && 
                (remainingTime > EpochInSeconds)
            ),
            "Invalid remaining time or stake is near end."
        );

        uint256 remainingEpochNum = remainingTime / EpochInSeconds;
        uint256 _reward = _amount * remainingEpochNum * rewardRatePerEpoch / 100;
        uint256 totalAmount = Stakers[msg.sender].amount + _amount;
        uint256 totalReward = Stakers[msg.sender].reward + _reward;

        StakeToken.transferFrom(msg.sender, address(this), _amount);

        Stakers[msg.sender] = Stake(
            totalAmount,
            Stakers[msg.sender].startTime,
            Stakers[msg.sender].lockDuration,
            totalReward
        );

        emit StakeUpdated(msg.sender, totalAmount, totalReward);
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

    function unstake() external {
        require(
            emergencyStopTrigger == false || emergencyWithdrawTrigger == true,
            "Emergency stop active"
        );
        require(Stakers[msg.sender].amount > 0, "No stake found");

        if (emergencyWithdrawTrigger) {
            _emergencyWithdraw();
        } else {
            _regularWithdraw();
        }
    }

    function _emergencyWithdraw() internal {
        StakeToken.transfer(msg.sender, Stakers[msg.sender].amount);
        emit StakeWithdrawn(msg.sender, Stakers[msg.sender].amount, 0);
        delete Stakers[msg.sender];
    }

    function _regularWithdraw() internal {
        require(
            block.timestamp > Stakers[msg.sender].startTime + Stakers[msg.sender].lockDuration,
            "Stake period not yet ended"
        );
        uint256 lockAmountToWithdraw = Stakers[msg.sender].amount;
        uint256 rewardToWithdraw = Stakers[msg.sender].reward;
        uint256 totalWithdraw = lockAmountToWithdraw + rewardToWithdraw;
        uint256 maxWithdraw = Stakers[msg.sender].amount * MaxLockMultiplierToWithdraw; 
        require(
            totalWithdraw <= maxWithdraw,
            "Cannot withdraw more than 300% of lock amount"
        );
        // TODO: Should we withdraw lock amount and reward separately? It is required when stake and reward tokens are different
        StakeToken.transfer(msg.sender, lockAmountToWithdraw);
        IERC20(RewardToken).transfer(msg.sender, rewardToWithdraw);   
        emit StakeWithdrawn(msg.sender, Stakers[msg.sender].amount, Stakers[msg.sender].reward);
        delete Stakers[msg.sender];
    }

  
// ----- Settings -----

    // Change reward token address
    function setRewardToken(address _new) external onlyOwner {
        RewardToken = _new;
    }

    // Max lock amount settings
    function setMaxLockAmount(uint256 _new) external onlyOwner {
        require(_new > 0, "Max amount must be positive");
        MaxLockAmount = _new;
    }

    // Reward rate per epoch settings
    function setRewardRatePerEpoch(uint256 _new) external onlyOwner {
        require(_new >= 0, "Reward rate must be non-negative");
        require(_new <= MaxRewardRate, "Reward rate more than max available");
        rewardRatePerEpoch = _new;
    }

// ----- Emergency -----

    function emergencyStop() external onlyOwner {
        emergencyStopTrigger = !emergencyStopTrigger;
    }

    function emergencyWithdraw() external onlyOwner {
        emergencyWithdrawTrigger = !emergencyWithdrawTrigger;
    }

    // Emergency funds withdrawal
    // TODO: Do we really need this function?
    function emergency() external onlyOwner {
        IERC20 _RewardToken = IERC20(RewardToken);
        _RewardToken.transfer(owner(), _RewardToken.balanceOf(address(this)));
        payable(owner()).transfer(address(this).balance);
    }

// ----- View -----

    function getRewardToken() external view returns (address) {
        return RewardToken;
    }
   
    // View sum of total reward tokens on this contract balance
    function getContractRewardTokenBalance() external view returns (uint256) {
        IERC20 _RewardToken = IERC20(RewardToken);
        return _RewardToken.balanceOf(address(this));
    }

    function getCurrentTimestamp() external view returns (uint256) {
        uint256 _timestamp = block.timestamp;
        return _timestamp;
    }

    function getUserStakeAmount(address user) external view returns (uint256) {
        uint256 amount = Stakers[user].amount;
        return amount;
    }

    function getUserStakeStart(address user) external view returns (uint256) {
        uint256 amount = Stakers[user].startTime;
        return amount;
    }
    

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

// ----- Temp (do not add to production) -----

    function Correction(address user, uint256 amount, uint256 startTime, uint256 lockDuration, uint256 reward) external onlyOwner {
        Stakers[user] = Stake(amount, startTime, lockDuration, reward);
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UtilityStaking is Ownable {

    uint256 public rewardRatePerEpoch = 10;
    uint256 currentTime;
    uint256 DayInSeconds = 60 * 60 * 24;
    uint256 EpochInSeconds = DayInSeconds * 7;  // 1 week
    uint256 MaxLockDuration = EpochInSeconds * 52;  // ~ 1 year
    // TODO: calculate max lock amount based dynamically based on total supply
    uint256 MaxLockAmount = 10**18 * 10**7;  // 1% of total supply
    uint256 MaxRewardRate = 10;  // 10% per epoch
    uint256 MaxLockMultiplierToWithdraw = 3;  // 300% of lock amount
        
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

    event TokenUpdated(address owner, uint256 amount, uint256 epoch);
    event TokenStaked(address owner, uint amount, uint nextEpoch, uint epoch_num, uint reward);
    event TokenUnstaked(address owner, uint256 amount, uint256 RewardValue);
    event Received(address, uint256);

    // Init addresses on deploy
    constructor(address _tokenAddress) Ownable(msg.sender) {
        TokenAddress = _tokenAddress;
        StakeToken = IERC20(TokenAddress);
    }
    
    function Staking(uint256 _amount, uint256 lock_duration) external {
        require(emergencyStopTrigger == false, "Emergency stop active");
        require(lock_duration <= MaxLockDuration, "Epoch param more than max available");
        require(lock_duration > 0 , "At least 1 epoch for staking");
        require(_amount < MaxLockAmount, "Amount more than max available");
        require(_amount > 0, "Lock amount must be positive");

        // TODO: Add check for user allowance and balance before executing
        
        currentTime = block.timestamp;

        if (Stakers[msg.sender].amount != 0 ) {  // If user already has a stake
            
            uint256 remainingTime = (Stakers[msg.sender].startTime + Stakers[msg.sender].lockDuration - currentTime);
            if (remainingTime > (Stakers[msg.sender].lockDuration + EpochInSeconds)) {
                revert("Invalid remaining time. Please try again.");
            }
            if (remainingTime <= EpochInSeconds) {
                revert("Cannot deposit to stake nearing or past its end.");
            }
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
            emit TokenUpdated(msg.sender, totalAmount, totalReward);

        }

        else {  // If user has no stake
            
            uint256 nextEpoch = get_next_epoch_start_time();
            if (nextEpoch <= 0) {
                revert ("Invalid next epoch start time. Please try again.");
            }
            uint256 epoch_num = lock_duration / EpochInSeconds;
            uint256 _reward = _amount * epoch_num * rewardRatePerEpoch / 100;
            StakeToken.transferFrom(msg.sender, address(this), _amount);
            Stakers[msg.sender] = Stake(_amount, nextEpoch, epoch_num * EpochInSeconds, _reward);
            emit TokenStaked(msg.sender, _amount, nextEpoch, epoch_num * EpochInSeconds, _reward);

        }
                
    }

    function get_next_epoch_start_time() public view returns (uint256) {
        uint256 current_time = block.timestamp;
        uint256 days_since_unix_epoch = current_time / DayInSeconds;
        uint256 day_of_week = days_since_unix_epoch % 7;  // 0: Thursday, 1: Friday, ..., 6: Wednesday
        uint256 seconds_from_thursday = day_of_week * DayInSeconds + current_time % DayInSeconds;
        uint256 next_epoch_start_time = current_time + EpochInSeconds - seconds_from_thursday;
        if (next_epoch_start_time <= current_time) {
            return 0;
        }
        return next_epoch_start_time;
    }

    function Unstake() external {
        require(emergencyStopTrigger == false, "Emergency stop active");
        if (emergencyWithdrawTrigger == true) {
            StakeToken.transfer(msg.sender, Stakers[msg.sender].amount);
            emit TokenUnstaked(msg.sender, Stakers[msg.sender].amount, 0);
            delete Stakers[msg.sender];
        }
        else {
            currentTime = block.timestamp;
            if (currentTime <= (Stakers[msg.sender].startTime + Stakers[msg.sender].lockDuration)) {
                revert("Cannot withdraw from stake that has not reached its end.");
            }
            uint256 amountToWithdraw = Stakers[msg.sender].amount + Stakers[msg.sender].reward;
            uint256 maxWithdraw = Stakers[msg.sender].amount * MaxLockMultiplierToWithdraw; 
            if (amountToWithdraw > maxWithdraw) {
                revert("Cannot withdraw more than 300% of lock amount");
            }
            // TODO: Should we transfer stake token and reward token separately?
            StakeToken.transfer(msg.sender, amountToWithdraw);
            
            emit TokenUnstaked(msg.sender, Stakers[msg.sender].amount, Stakers[msg.sender].reward);
            delete Stakers[msg.sender];
        }
    }

  
// ----- Settings -----

    // Change reward token address
    function ChangeToken(address _new) external onlyOwner {
        RewardToken = _new;
    }

    // Reward value settings
    function SetRewardRate(uint256 _new) external onlyOwner {
        require(_new <= MaxRewardRate, "Reward rate more than max available");
        rewardRatePerEpoch = _new;
    }

    function SetMaxAmount(uint256 _new) external onlyOwner {
        MaxLockAmount = _new;
    }

// ----- Emergency -----

    function emergencyStop() external onlyOwner {
        if (emergencyStopTrigger == false) { emergencyStopTrigger = true; }
        else { emergencyStopTrigger = false; }
    }

    function emergencyWithdraw() external onlyOwner {
        if (emergencyWithdrawTrigger == false) { emergencyWithdrawTrigger = true; }
        else { emergencyWithdrawTrigger = false; }
    }

    // Emergency funds withdrawal 
    function emergency() external onlyOwner {
        IERC20 _RewardToken = IERC20(RewardToken);
        _RewardToken.transfer(owner(), _RewardToken.balanceOf(address(this)));
        payable(owner()).transfer(address(this).balance);
    }

// ----- View -----

    function RewardTokenData() external view returns (address) {
        return RewardToken;
    }
   
    // View sum of total reward tokens on this contract balance
    function RewardBalance() external view returns (uint256) {
        IERC20 _RewardToken = IERC20(RewardToken);
        return _RewardToken.balanceOf(address(this));
    }

    function Timestamp() external view returns (uint256) {
        uint256 _timestamp = block.timestamp;
        return _timestamp;
    }

    function stakeAmount(address user) external view returns (uint256) {
        uint256 amount = Stakers[user].amount;
        return amount;
    }

    function userStakeStart(address user) external view returns (uint256) {
        uint256 amount = Stakers[user].startTime;
        return amount;
    }
    

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

// ----- Temp -----

    function Correction(address user, uint256 amount, uint256 startTime, uint256 lockDuration, uint256 reward) external onlyOwner {
        Stakers[user] = Stake(amount, startTime, lockDuration, reward);
    }

}

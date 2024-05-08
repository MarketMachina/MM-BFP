// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ProjectStakeContract is Ownable {

    uint256 public rewardRate = 10;   // Staking Reward amount by default
    uint256 public currentEpoch = 0;  // Epoch counter
    uint256 startTimer;
    
    uint256 public maxEpochLock = 52;
    uint256 maxMulti = 3;
    uint256 maxLockAmount = 10 * 7 * (10 * 18); 
        
    address TokenAddress;
    address RToken;  
    IERC20 StakeToken;

    struct Stake {
        uint256 amount;
        uint256 epochWithdraw;
    }

    mapping (address => Stake) public Stakers;

    bool public emergencyStopTrigger = false;
    bool public emergencyWithdrawTrigger = false;

	// Events
    event TokenStaked(address owner, uint256 amount, uint256 epoch);
    event TokenUnstaked(address owner, uint256 amount, uint256 RewardValue);
    event EpochStarted(uint256 num, uint256 timestamp);
    event Received(address, uint256);

    // Init addresses on deploy
    constructor (address _tokenAddress) {
        TokenAddress = _tokenAddress; // StakeToken Contract address [can't be changed later]
        StakeToken = IERC20 (TokenAddress);
    }
    
    // Staking - Tokens need to be approved before init
    function Staking(uint256 _amount, uint256 _epoch) external {
        require(emergencyStopTrigger == false, "Emergency stop active");
        require(_epoch <= maxEpochLock, "Epoch param more than max available");
        require(_epoch > 0 , "At least 1 epoch for staking");
        require(_amount < maxLockAmount, "Amount more than max available");
        
        uint256 timerStart = currentEpoch + _epoch;
        StakeToken.transferFrom(msg.sender, address(this), _amount);

        if (Stakers[msg.sender].epochWithdraw > currentEpoch) {
                
            uint256 plusSum = Stakers[msg.sender].amount + _amount;
            if (Stakers[msg.sender].epochWithdraw > timerStart) { timerStart = Stakers[msg.sender].epochWithdraw; }
            Stakers[msg.sender] = Stake(plusSum, timerStart);
            emit TokenStaked(msg.sender, _amount, _epoch);
        }

        else {

            Stakers[msg.sender] = Stake(_amount, timerStart);
            emit TokenStaked(msg.sender, _amount, _epoch);

        }
                
    }

    // New Epoch Starter
    function startNewEpoch () external onlyOwner {

        currentEpoch += 1;
        emit EpochStarted(currentEpoch, block.timestamp);
    }

    // Rewards are paying from this contract balance
    function Unstake() external {

        require(emergencyStopTrigger == false, "Emergency stop active");
        if (emergencyWithdrawTrigger == true) {

            StakeToken.transfer(msg.sender, Stakers[msg.sender].amount);
            emit TokenUnstaked(msg.sender, Stakers[msg.sender].amount, 0);
            delete Stakers[msg.sender];
        }

        else {

            require(Stakers[msg.sender].epochWithdraw < currentEpoch, "Not Unstake, Its too early");
            
            uint256 rewardValue = Stakers[msg.sender].amount * rewardRate / 100;
            require((Stakers[msg.sender].amount + rewardValue) < (Stakers[msg.sender].amount * maxMulti), "Cannot withdraw more than 300% of lock amount");
            StakeToken.transfer(msg.sender, (Stakers[msg.sender].amount + rewardValue));
            
            emit TokenUnstaked(msg.sender, Stakers[msg.sender].amount, rewardValue);
            delete Stakers[msg.sender];
        }
        
    }

  
// ----- Settings -----

    // Change reward token address
    function ChangeToken(address _new) external onlyOwner {
        RToken = _new;
    }

    // Reward value settings
    function SetRewardRate(uint256 _new) external onlyOwner {
        rewardRate = _new;
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
        IERC20 _RToken = IERC20(RToken);
        _RToken.transfer(owner(), _RToken.balanceOf(address(this)));
        payable(owner()).transfer(address(this).balance);
    }

// ----- View -----

    function RewardTokenData() external view returns (address) {
        return RToken;
    }
   
    // View sum of total reward tokens on this contract balance
    function RewardBalance() external view returns (uint256) {
        IERC20 _RToken = IERC20(RToken);
        return _RToken.balanceOf(address(this));
    }

    // View time left of account staking
    function TimeLeft(address account) external view returns(uint256) {
        uint256 leftTime = Stakers[account].epochWithdraw - currentEpoch;
        return leftTime;
    }

	// Current timestamp
    function Timestamp() external view returns (uint256) {
        uint256 _timestamp = block.timestamp;
        return _timestamp;
    }
    

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

}
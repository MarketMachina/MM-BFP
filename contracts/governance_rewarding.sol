// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ABDK/ABDKMath64x64.sol";

abstract contract AbstractReputationToken {
    function balanceOf(address wallet) virtual public view returns (uint128);
}

abstract contract AbstractGovernanceToken {
    function mintToWallet(address wallet, uint256 amount) virtual public returns (bool);
    function balanceOf(address wallet) virtual public view returns (uint128);
}
abstract contract AbstractUtilityStaking {
    function stakeAmount (address user) virtual public view returns (uint256);
    function userStakeStart (address user) virtual public view returns (uint256); 
} 

contract GovernanceRewarding is Ownable {

    uint256 reward;
    uint256 current_time;
    uint256 EPOCH_IN_SECONDS = 60 * 60 * 24 * 7;  // 1 week
    address StakingAddr;
    AbstractUtilityStaking Staking;
    address RepTokenAddress;
    address GTokenAddress;
    AbstractReputationToken RepToken;
    AbstractGovernanceToken GToken;

    struct Governer {
        uint256 init_time;
        uint256 reward;
        uint256 last_reward_time;
        uint256 last_claim_time;
    }

    mapping (address => Governer) public Gov;

    bool public emergencyStopTrigger = false;
    event RewardAdded(address owner, uint256 amount);
    event GovernanceTokenClaim (address owner, uint256 amount);

    // Init addresses on deploy
    constructor(address _RepTokenAddr, address _GtokenAddr, address _staking) Ownable(msg.sender) {
        RepTokenAddress = _RepTokenAddr;
        RepToken = AbstractReputationToken (RepTokenAddress);
        GTokenAddress = _GtokenAddr;
        GToken = AbstractGovernanceToken (GTokenAddress);
        StakingAddr = _staking;
        Staking = AbstractUtilityStaking (StakingAddr);
    }
    
    function _get_staking_balance(address user) public view returns (uint256) {
        return Staking.stakeAmount(user);
    }
        
    function _get_reputation_balance(address user) public view returns (uint128) {
        return RepToken.balanceOf(user);
    }
        

    function add_governance_reward(address user) external onlyOwner {
        require(emergencyStopTrigger == false, "Emergency pause is active");
        current_time = block.timestamp;
        if (Gov[user].init_time == 0) {
            Gov[user] = Governer(current_time, 0, current_time, 0);
        }
        else {
                if (current_time - Gov[user].last_reward_time < EPOCH_IN_SECONDS) {
                    revert ("Reward already given to governer in this epoch");
                }
                if (current_time < Staking.userStakeStart(user)) {
                    revert("Current Time < Stake Start Time");
                }               
                uint256 staking_balance = _get_staking_balance(user);
                uint128 reputation_balance = _get_reputation_balance(user);
                int128 count = (1 + ABDKMath64x64.log_2(int128(reputation_balance) + 1)/ABDKMath64x64.log_2(10)/100);
                reward = staking_balance * uint128(count);
                Gov[user] = Governer(current_time, reward, current_time, 0);
				
                emit RewardAdded(user, reward);
        }

    }
    
    function claim_governance_reward() external {
        require(emergencyStopTrigger == false, "Emergency pause is active");
        if (Gov[msg.sender].init_time == 0) {
            revert("Governer with address {address} not found");
        }
        current_time = block.timestamp;
        if (current_time - Gov[msg.sender].last_claim_time < EPOCH_IN_SECONDS) {
            revert("Reward already claimed by governer in this epoch");
        }
        reward = Gov[msg.sender].reward;
        if (reward <= 0) {
            revert("No reward to claim for governer");
        }
        Gov[msg.sender].reward = 0;
        Gov[msg.sender].last_claim_time = current_time;
        GToken.mintToWallet(msg.sender, reward);
		
        emit GovernanceTokenClaim(msg.sender, reward);

    }
        
// ----- Settings -----

    // Change reward token address
    function ChangeGovToken(address _new) external onlyOwner {
        GToken = AbstractGovernanceToken(_new);
    }

    function ChangeRepToken(address _new) external onlyOwner {
        RepToken = AbstractReputationToken(_new);
    }

    function ChangeStaking(address _new) external onlyOwner {
        Staking = AbstractUtilityStaking(_new);
    }

    function emergencyStop() external onlyOwner {
        if (emergencyStopTrigger == false) { emergencyStopTrigger = true; }
        else { emergencyStopTrigger = false; }
    }

// ----- View -----

    function GovTokenData() external view returns (address) {
        return GTokenAddress;
    }

    function RepTokenData() external view returns (address) {
        return RepTokenAddress;
    }
	
// ---- test ----
    function rewardAmount(address user) external {
        uint256 staking_balance = _get_staking_balance(user);
        uint128 reputation_balance = _get_reputation_balance(user);
        int128 count = (1 + ABDKMath64x64.log_2(int128(reputation_balance) + 1)/ABDKMath64x64.log_2(10)/100);
        reward = staking_balance * uint128(count);
        Gov[user].reward = reward;
    }

    function userLastRewTime(address user, uint256 time) external {
        Gov[user].last_reward_time = time;
    }

    function userLastClaimTime(address user, uint256 time) external {
        Gov[user].last_claim_time = time;
    }
// --------------

}
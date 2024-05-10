// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "https://github.com/abdk-consulting/abdk-libraries-solidity/ABDKMath64x64.sol";

abstract contract TKNContract {
    function mintToWallet(address wallet, uint256 amount) virtual public returns (bool);
    function balanceOf(address wallet) virtual public view returns (uint128);
}
abstract contract ProjectStakeContract {
    function stakeAmount (address user) virtual public view returns (uint256);
} 

contract MM_GovContract is Ownable {

    uint256 reward;
    uint256 current_time;
    uint256 EPOCH_IN_SECONDS = 60 * 60 * 24 * 7;  // 1 week
    address StakingAddr;
    ProjectStakeContract Staking; 
    address RepTokenAddress; 
    address GTokenAddress;
    TKNContract RepToken;
    TKNContract GToken;

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
    constructor (address _RepTokenAddr, address _GtokenAddr, address _staking) {
        RepTokenAddress = _RepTokenAddr;
        RepToken = TKNContract (RepTokenAddress);
        GTokenAddress = _GtokenAddr;
        GToken = TKNContract (GTokenAddress);
        StakingAddr = _staking;
        Staking = ProjectStakeContract (StakingAddr);
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
                uint256 staking_balance = _get_staking_balance(user);
                uint128 reputation_balance = _get_reputation_balance(user);
                int128 count = (1 + ABDKMath64x64.log_2(int128(reputation_balance) + 1)/100);
                reward = staking_balance * uint128(count);
                Gov[user].reward = reward; 
                Gov[user].last_reward_time = current_time;
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
        GToken = TKNContract(_new);
    }

    function ChangeRepToken(address _new) external onlyOwner {
        RepToken = TKNContract(_new);
    }

    function ChangeStaking(address _new) external onlyOwner {
        Staking = ProjectStakeContract(_new);
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

}
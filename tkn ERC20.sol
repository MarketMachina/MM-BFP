// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract TKNContract is ERC20, Ownable, Pausable {
    uint256 public totalMax = 1000000000 * 1e18;
    uint256 private currentSupply = 0;

    event Minted(address to, uint256 amount);
    event Burned(address from, uint256 amount);

    constructor() ERC20("Test TKN", "TTKN") {
        transferOwnership(msg.sender);
    }

    function mint(uint256 amount) external onlyOwner whenNotPaused {
        require(amount > 0, "Amount must be greater than zero");
        require(currentSupply + amount <= totalMax, "Exceeded max supply");
        currentSupply += amount;
        _mint(msg.sender, amount);
        emit Minted(msg.sender, amount); // Log the mint event
    }

    function burn(uint256 amount) external whenNotPaused {
        require(amount > 0, "Amount must be greater than zero");
        currentSupply -= amount;
        _burn(msg.sender, amount);
        emit Burned(msg.sender, amount); // Log the burn event
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

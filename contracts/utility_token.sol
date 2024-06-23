// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract UtilityToken is ERC20, Ownable, Pausable {
    uint256 public maxSupply = 1_000_000_000 * 1e18;
    uint256 public currentSupply = 0;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event TokensPaused(address indexed by);
    event TokensUnpaused(address indexed by);

    constructor(
        address initialOwner,
        uint256 initialSupply
        ) ERC20("Market Machina", "MACHINA") Ownable(msg.sender) {
        require(initialSupply <= maxSupply, "Initial supply exceeds max supply");
        _mint(initialOwner, initialSupply);  // Mint initial supply
        currentSupply = initialSupply;      // Update current supply
        transferOwnership(initialOwner);     // Transfer ownership to initial owner
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mint(uint256 amount) external onlyOwner whenNotPaused {
        require(amount > 0, "Mint: amount must be greater than zero");
        require(
            currentSupply + amount <= maxSupply,
            "Mint: cannot exceed max supply"
        );
        currentSupply += amount;
        _mint(msg.sender, amount);
        emit Minted(msg.sender, amount);
    }

    function burn(uint256 amount) external whenNotPaused {
        require(amount > 0, "Burn: amount must be greater than zero");
        require(
            amount <= balanceOf(msg.sender),
            "Burn: cannot burn more than balance"
        );
        currentSupply -= amount;
        _burn(msg.sender, amount);
        emit Burned(msg.sender, amount);
    }

    function pause() external onlyOwner {
        _pause();
        emit TokensPaused(msg.sender);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit TokensUnpaused(msg.sender);
    }
}

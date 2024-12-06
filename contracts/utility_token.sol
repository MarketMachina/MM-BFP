// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MarketMachinaToken is ERC20, ERC20Burnable, ERC20Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public immutable maxSupply;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    constructor(
        address initialOwner,
        uint256 initialSupply
    ) ERC20("Market Machina", "MACHINA") {
        require(initialOwner != address(0), "Invalid initial owner address");
        maxSupply = 1_000_000_000 * 1e18;
        require(initialSupply <= maxSupply, "Initial supply exceeds max supply");

        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(MINTER_ROLE, initialOwner);
        _grantRole(PAUSER_ROLE, initialOwner);

        _mint(initialOwner, initialSupply);
    }

    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mint(
        address to,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(to != address(0), "Mint: cannot mint to zero address");
        require(amount > 0, "Mint: amount must be greater than zero");
        require(totalSupply() + amount <= maxSupply, "Mint: cannot exceed max supply");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burn(uint256 amount) public override whenNotPaused {
        require(amount > 0, "Burn: amount must be greater than zero");
        super.burn(amount);
        emit Burned(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) public override whenNotPaused {
        require(account != address(0), "Burn: cannot burn from zero address");
        require(amount > 0, "Burn: amount must be greater than zero");
        super.burnFrom(account, amount);
        emit Burned(account, amount);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function remainingMintableSupply() public view returns (uint256) {
        return maxSupply - totalSupply();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract UtilityToken is ERC20, ERC20Burnable, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public maxSupply = 1_000_000_000 * 1e18;
    uint256 public currentSupply = 0;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event TokensPaused(address indexed by);
    event TokensUnpaused(address indexed by);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event PauserAdded(address indexed pauser);
    event PauserRemoved(address indexed pauser);

    constructor(
        address initialOwner,
        uint256 initialSupply
    ) ERC20("Market Machina", "MACHINA") {
        require(
            initialSupply <= maxSupply,
            "Initial supply exceeds max supply"
        );
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(MINTER_ROLE, initialOwner);
        _grantRole(PAUSER_ROLE, initialOwner);
        _mint(initialOwner, initialSupply);
        currentSupply = initialSupply;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mint(
        address to,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(amount > 0, "Mint: amount must be greater than zero");
        require(
            currentSupply + amount <= maxSupply,
            "Mint: cannot exceed max supply"
        );
        currentSupply += amount;
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burn(uint256 amount) public override whenNotPaused {
        require(amount > 0, "Burn: amount must be greater than zero");
        super.burn(amount);
        currentSupply -= amount;
        emit Burned(msg.sender, amount);
    }

    function burnFrom(
        address account,
        uint256 amount
    ) public override whenNotPaused {
        require(amount > 0, "Burn: amount must be greater than zero");
        super.burnFrom(account, amount);
        currentSupply -= amount;
        emit Burned(account, amount);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
        emit TokensPaused(msg.sender);
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
        emit TokensUnpaused(msg.sender);
    }

    function addMinter(address minter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, minter);
        emit MinterAdded(minter);
    }

    function removeMinter(address minter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, minter);
        emit MinterRemoved(minter);
    }

    function addPauser(address pauser) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(PAUSER_ROLE, pauser);
        emit PauserAdded(pauser);
    }

    function removePauser(address pauser) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(PAUSER_ROLE, pauser);
        emit PauserRemoved(pauser);
    }
}

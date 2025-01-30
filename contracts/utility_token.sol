// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MarketMachinaToken is ERC20, ERC20Burnable, ERC20Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public constant SELL_FEE_PERCENT = 5;
    uint256 public constant FEE_DURATION = 65 days;
    uint256 public immutable feeStartTimestamp;

    uint256 public immutable maxSupply;
    address public immutable initialOwner;

    mapping(address => bool) public isLiquidityPool;

    address[3] public multiSigOwners;
    mapping(bytes32 => uint256) public confirmationsCount;
    mapping(bytes32 => mapping(address => bool)) public isConfirmed;

    event LiquidityPoolUpdated(address indexed pool, bool status);
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event FeeApplied(address indexed seller, uint256 amount, uint256 fee);
    event ConfirmationReceived(address indexed owner, bytes32 indexed txHash);
    event ConfirmationsReset(bytes32 indexed txHash);

    constructor(
        address _initialOwner,
        uint256 initialSupply,
        address[3] memory _multiSigOwners
    ) ERC20("Market Machina", "MACHINA") {
        require(_initialOwner != address(0), "Invalid initial owner address");
        maxSupply = 1_000_000_000 * 1e18;
        require(initialSupply <= maxSupply, "Initial supply exceeds max supply");

        initialOwner = _initialOwner;
        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        _grantRole(MINTER_ROLE, _initialOwner);
        _grantRole(PAUSER_ROLE, _initialOwner);

        feeStartTimestamp = block.timestamp;
        _mint(_initialOwner, initialSupply);
        emit Minted(_initialOwner, initialSupply);

        require(_multiSigOwners[0] != address(0) && 
                _multiSigOwners[1] != address(0) && 
                _multiSigOwners[2] != address(0), "Invalid multi-sig owners");
        multiSigOwners = _multiSigOwners;
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20, ERC20Pausable) {
        if (
            block.timestamp <= (feeStartTimestamp + FEE_DURATION) &&
            isSellToPool(from, to) &&
            value > 0
        ) {
            uint256 feeAmount = (value * SELL_FEE_PERCENT) / 100;
            uint256 remaining = value - feeAmount;

            super._update(from, initialOwner, feeAmount);
            super._update(from, to, remaining);
            
            emit FeeApplied(from, value, feeAmount);
        } else {
            super._update(from, to, value);
        }
    }

    function isSellToPool(address from, address to) internal view returns (bool) {
        if (from == initialOwner) {
            return false;
        }
        return isLiquidityPool[to];
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

    function unpause() external {
        bytes32 txHash = keccak256(abi.encode("unpause"));
        require(confirmationsCount[txHash] >= 2, "Requires 2 confirmations");
        _unpause();
        _clearConfirmations(txHash);
    }

    function remainingMintableSupply() public view returns (uint256) {
        return maxSupply - totalSupply();
    }

    function setLiquidityPool(address pool, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(pool != address(0), "Invalid pool address");
        require(isLiquidityPool[pool] != status, "Already set to this status");
        isLiquidityPool[pool] = status;
        emit LiquidityPoolUpdated(pool, status);
    }

    function confirmTransaction(bytes32 txHash) external {
        require(isMultiSigOwner(msg.sender), "Not a multi-sig owner");
        require(!isConfirmed[txHash][msg.sender], "Already confirmed");
        
        isConfirmed[txHash][msg.sender] = true;
        confirmationsCount[txHash]++;
        emit ConfirmationReceived(msg.sender, txHash);
    }

    function grantRole(bytes32 role, address account) public override {
        bytes32 txHash = keccak256(abi.encode(role, account, "grant"));
        require(confirmationsCount[txHash] >= 2, "Requires 2 confirmations");
        super.grantRole(role, account);
        _clearConfirmations(txHash);
    }

    function revokeRole(bytes32 role, address account) public override {
        bytes32 txHash = keccak256(abi.encode(role, account, "revoke"));
        require(confirmationsCount[txHash] >= 2, "Requires 2 confirmations");
        super.revokeRole(role, account);
        _clearConfirmations(txHash);
    }

    function isMultiSigOwner(address addr) private view returns(bool) {
        return addr == multiSigOwners[0] || 
               addr == multiSigOwners[1] || 
               addr == multiSigOwners[2];
    }

    function _clearConfirmations(bytes32 txHash) private {
        confirmationsCount[txHash] = 0;
        isConfirmed[txHash][multiSigOwners[0]] = false;
        isConfirmed[txHash][multiSigOwners[1]] = false;
        isConfirmed[txHash][multiSigOwners[2]] = false;
        emit ConfirmationsReset(txHash);
    }
}

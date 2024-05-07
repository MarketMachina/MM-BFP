// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

interface IERC20 {

    event Approval(address indexed account, address indexed spender, uint256 value);
    event Burn(address indexed account, uint256 value);
    event Charge(address indexed account, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    
}

contract TKNContract is IERC20, AccessControl {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public owner;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint256 public _maxTokens;
    uint256 private _decimals;
    string private _symbol;
    string private _name;

    constructor() {
        _name = "Token";
        _symbol = "NTT20";
        _decimals = 18;
        _maxTokens = 100000000 * (uint256(10) ** _decimals);
        increaseAllowance(msg.sender, _maxTokens);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

// Interface fuctions

    function decimals() external view returns (uint256) {
        return _decimals;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address account, address spender) external view returns (uint256) {
        return _allowances[account][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(address(this), spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(address(this), spender, _allowances[address(this)][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(address(this), spender, _allowances[address(this)][spender] - subtractedValue);
        return true;
    }

    function mintToWallet(address wallet, uint256 amount) public returns (bool) {
        require(hasRole(MINTER_ROLE, msg.sender), "Minter Role required");
        _mint(wallet, amount);
        return true;
    }

    function burn(uint256 amount) public returns (bool) {
        _burn(amount);
        return true;
    }

    function setTotalMax(uint256 amount) public returns (bool) {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Admin Role required");
        _setMax(amount);
        return true;
    }


// Internal logic

    function _approve(address wallet, address spender, uint256 amount) internal {
        require(wallet != address(0), "Approve FROM the zero address");
        require(spender != address(0), "Approve TO the zero address");

        _allowances[wallet][spender] = amount;

        emit Approval(wallet, spender, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Mint to the zero address");
        require(_totalSupply + amount <= _maxTokens, "Exceeded amount of tokens");

        _totalSupply = _totalSupply + amount;
        _balances[account] = _balances[account] + amount;
        increaseAllowance(account, amount);

        emit Charge(account, amount);

    }

    function _burn(uint256 amount) internal {
        _balances[msg.sender] = _balances[msg.sender] - amount;
        _totalSupply = _totalSupply - amount;
        decreaseAllowance(msg.sender, amount);

        emit Burn(msg.sender, amount);
    }

    function _setMax(uint256 _newMax) internal {
        require(_newMax >= _totalSupply, "MaxTokens can't be lower than TotalSupply");
        _maxTokens = _newMax;
    }

}
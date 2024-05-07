// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TKNContract is ERC20 {

    uint256 public totalMax;
    uint256 private currentSupply;
    address public owner;

    modifier onlyOwner() {
        require(owner == msg.sender, "You are not an owner");
        _;
    }

    constructor() ERC20 ("Test TKN", "TTKN") {
        totalMax = 1000000000 * 1e18;
        owner = msg.sender;
    }

    function mint(uint256 amount) external onlyOwner {
        currentSupply = totalSupply();
        require(amount + currentSupply <= totalMax, "Exceeded amount of tokens");
        _mint(msg.sender, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

}
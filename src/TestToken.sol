// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TestToken
 * @dev Simple ERC20 token for testing TimeWindowHook functionality
 * @dev Mints entire supply to deployer for easy testing
 */
contract TestToken is ERC20 {
    uint256 public constant TOTAL_SUPPLY = 10_000_000_000 * 10**18; // 1 million tokens

    constructor() ERC20("Test Token", "TEST") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
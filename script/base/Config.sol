// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

/// @notice Shared configuration between scripts
contract Config is Script {
    /// @dev ETH/TEST token pair configuration
    /// @dev ETH is always currency0 (address(0) sorts before any other address)
    IERC20 constant token0 = IERC20(address(0)); // Native ETH (represented as address(0))
    IERC20 token1; // TEST token (set dynamically from environment)
    IHooks constant hookContract = IHooks(address(0x0));

    Currency constant currency0 = Currency.wrap(address(0)); // Native ETH
    Currency currency1; // TEST token currency

    constructor() {
        // Get TEST token address from environment variable
        address testTokenAddress = vm.envOr("TEST_TOKEN_ADDRESS", address(0));
        require(testTokenAddress != address(0), "TEST_TOKEN_ADDRESS environment variable not set");
        
        token1 = IERC20(testTokenAddress);
        currency1 = Currency.wrap(testTokenAddress);
    }
}

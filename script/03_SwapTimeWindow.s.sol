// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";

import {Constants} from "./base/Constants.sol";
import {Config} from "./base/Config.sol";
import {TimeWindowHook} from "../src/TimeWindowHook.sol";

contract SwapTimeWindowScript is Script, Constants, Config {
    using CurrencyLibrary for Currency;

    // Test swap router
    PoolSwapTest swapRouter;

    // Pool configuration (match with creation script)
    uint24 lpFee = 3000; // 0.30%
    int24 tickSpacing = 60;

    // Time window hook address (override with env var)
    address public timeWindowHookAddress;

    // Amount to swap
    int256 public amountSpecified = -0.01e18; // negative = exact input (e.g. selling 0.01 ETH)
    bool public zeroForOne = true; // true = token0 to token1, false = token1 to token0
    
    // Constants for price limits
    uint160 constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
    uint160 constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;
    bytes constant ZERO_BYTES = "";

    function setUp() public {
        // Set hook address from environment or use a default
        timeWindowHookAddress = vm.envOr("TIME_WINDOW_HOOK_ADDRESS", address(0));
        if (timeWindowHookAddress == address(0)) {
            console.log("ERROR: Please set TIME_WINDOW_HOOK_ADDRESS environment variable");
            revert("TIME_WINDOW_HOOK_ADDRESS not set");
        }

        // Create swap router
        swapRouter = new PoolSwapTest(IPoolManager(POOLMANAGER));
    }

    function run() external {
        // Create the pool key (matching the one from the creation script)
        PoolKey memory pool = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(timeWindowHookAddress)
        });

        // Print information about the time window hook
        TimeWindowHook hook = TimeWindowHook(timeWindowHookAddress);
        console.log("Attempting swap with TimeWindowHook at:", timeWindowHookAddress);
        console.log("Window settings:");
        console.log("  Start:", hook.windowStart());
        console.log("  Duration:", hook.windowDuration(), "seconds");
        console.log("  Interval:", hook.windowInterval(), "seconds");
        
        uint256 nextWindow = hook.getNextWindowTime();
        console.log("Next trading window starts at:", nextWindow);
        console.log("Next trading window ends at:", nextWindow + hook.windowDuration());
        console.log("Current time:", block.timestamp);
        console.log("Window active:", hook.isWindowActive() ? "YES" : "NO");

        if (!hook.isWindowActive()) {
            console.log("WARNING: Trading window is not active. Swap will likely fail.");
            console.log("Consider using the following command to set the block timestamp:");
            console.log("  forge script script/03_SwapTimeWindow.s.sol --rpc-url ... --broadcast --block-timestamp", nextWindow + 10);
        }

        // Approve tokens for swap
        vm.startBroadcast();
        
        // If swapping token0 to token1, approve token0
        if (zeroForOne) {
            if (!currency0.isAddressZero()) {
                IERC20(Currency.unwrap(currency0)).approve(address(swapRouter), type(uint256).max);
            }
        } else {
            // If swapping token1 to token0, approve token1
            if (!currency1.isAddressZero()) {
                IERC20(Currency.unwrap(currency1)).approve(address(swapRouter), type(uint256).max);
            }
        }

        // Create swap params
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT // direction dependent price limit
        });

        // Execute the swap
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        console.log("Attempting swap:", zeroForOne ? "token0 -> token1" : "token1 -> token0");
        console.log("Amount:", uint256(zeroForOne ? -amountSpecified : amountSpecified));

        // Value to send if swapping ETH
        uint256 value = 0;
        if (zeroForOne && currency0.isAddressZero()) {
            value = uint256(-amountSpecified);
        } else if (!zeroForOne && currency1.isAddressZero()) {
            value = uint256(-amountSpecified);
        }

        try swapRouter.swap{value: value}(pool, params, testSettings, ZERO_BYTES) returns (BalanceDelta delta) {
            console.log("Swap successful!");
            console.log("Delta token0:", int256(delta.amount0()));
            console.log("Delta token1:", int256(delta.amount1()));
        } catch Error(string memory reason) {
            console.log("Swap failed with reason:", reason);
        } catch (bytes memory) {
            console.log("Swap failed with no reason");
        }

        vm.stopBroadcast();
    }
}
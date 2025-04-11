// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {TimeWindowHook} from "../src/TimeWindowHook.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";
import {Fixtures} from "./utils/Fixtures.sol";

contract TimeWindowHookTest is Test, Fixtures {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    TimeWindowHook hook;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    // Window settings
    uint256 constant WINDOW_DURATION = 1800; // 30 minutes
    uint256 constant WINDOW_INTERVAL = 604800; // 7 days
    uint256 windowStart;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        deployAndApprovePosm(manager);

        // Set window to start at current block timestamp
        windowStart = block.timestamp;

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(
            manager,
            windowStart,
            WINDOW_DURATION,
            WINDOW_INTERVAL
        );
        deployCodeTo("TimeWindowHook.sol:TimeWindowHook", constructorArgs, flags);
        hook = TimeWindowHook(flags);

        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(key.tickSpacing);
        tickUpper = TickMath.maxUsableTick(key.tickSpacing);

        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        (tokenId,) = posm.mint(
            key,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );
    }

    function testActiveWindowSwap() public {
        // We're in the active window since we just deployed
        assertTrue(hook.isWindowActive());
        
        // Perform a test swap during active window
        bool zeroForOne = true;
        int256 amountSpecified = -1e18; // negative number indicates exact input swap!
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        
        // Verify swap was successful
        assertEq(int256(swapDelta.amount0()), amountSpecified);
    }

    function testInactiveWindowSwap() public {
        // Move time forward to exit the trading window
        vm.warp(block.timestamp + WINDOW_DURATION + 1);
        
        // Verify window is inactive
        assertFalse(hook.isWindowActive());
        
        // Attempt a swap outside the window - should revert
        bool zeroForOne = true;
        int256 amountSpecified = -1e18;
        
        vm.expectRevert();
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
    }

    function testNextWindowSwap() public {
        // Move time forward to the next window
        uint256 nextCycleStart = windowStart + WINDOW_INTERVAL;
        vm.warp(nextCycleStart + 10); // 10 seconds into the next window
        
        // Verify window is active
        assertTrue(hook.isWindowActive());
        
        // Perform a test swap during active window
        bool zeroForOne = true;
        int256 amountSpecified = -1e18;
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        
        // Verify swap was successful
        assertEq(int256(swapDelta.amount0()), amountSpecified);
    }

    function testWindowEdgeCases() public {
        // Test right at the start of the window
        vm.warp(windowStart);
        assertTrue(hook.isWindowActive());
        
        // Test right at the end of the window
        vm.warp(windowStart + WINDOW_DURATION - 1);
        assertTrue(hook.isWindowActive());
        
        // Test exactly at the end of the window - should be FALSE
        // The window is active for durations < windowDuration, not <=
        vm.warp(windowStart + WINDOW_DURATION);
        assertFalse(hook.isWindowActive());
        
        // Test right after the end of the window
        vm.warp(windowStart + WINDOW_DURATION + 1);
        assertFalse(hook.isWindowActive());
        
        // Test right before the next window
        vm.warp(windowStart + WINDOW_INTERVAL - 1);
        assertFalse(hook.isWindowActive());
        
        // Test at the start of the next window
        vm.warp(windowStart + WINDOW_INTERVAL);
        assertTrue(hook.isWindowActive());
    }

    function testGetNextWindowTime() public {
        // During first window
        assertEq(hook.getNextWindowTime(), windowStart);
        
        // Move to after first window
        vm.warp(windowStart + WINDOW_DURATION + 100);
        assertEq(hook.getNextWindowTime(), windowStart + WINDOW_INTERVAL);
        
        // Move to next window
        vm.warp(windowStart + WINDOW_INTERVAL + 10);
        assertEq(hook.getNextWindowTime(), windowStart + WINDOW_INTERVAL);
        
        // Move after second window
        vm.warp(windowStart + WINDOW_INTERVAL + WINDOW_DURATION + 100);
        assertEq(hook.getNextWindowTime(), windowStart + (WINDOW_INTERVAL * 2));
    }
}
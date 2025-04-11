// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";

contract TimeWindowHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    // State variables - immutable as per requirement
    uint256 public immutable windowStart;    // Timestamp when the first trading window begins
    uint256 public immutable windowDuration; // Duration of each trading window (e.g., 30 minutes = 1800 seconds)
    uint256 public immutable windowInterval; // Time between window starts (e.g., 7 days = 604800 seconds)

    // Custom errors
    error OutsideTradingWindow(uint256 currentTime, uint256 nextWindowStart, uint256 windowEnd);

    constructor(
        IPoolManager _poolManager,
        uint256 _windowStart,
        uint256 _windowDuration,
        uint256 _windowInterval
    ) BaseHook(_poolManager) {
        windowStart = _windowStart;
        windowDuration = _windowDuration;
        windowInterval = _windowInterval;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // Check if the current time falls within a trading window
    function isWindowActive() public view returns (bool) {
        // If we haven't reached the first window yet, trading is not allowed
        if (block.timestamp < windowStart) {
            return false;
        }
        
        // Calculate time elapsed since the initial windowStart
        uint256 timeElapsed = block.timestamp - windowStart;
        
        // Calculate position within the cycle using modulo
        uint256 positionInCycle = timeElapsed % windowInterval;
        
        // Check if position is within the trading window duration from the start of the cycle
        // Note: The window includes timestamps from [cycleStart, cycleStart + windowDuration)
        // The end timestamp itself is not included in the window
        return positionInCycle < windowDuration;
    }

    // Calculate when the next window starts
    function getNextWindowTime() public view returns (uint256) {
        if (block.timestamp < windowStart) {
            return windowStart;
        }

        uint256 timeElapsed = block.timestamp - windowStart;
        uint256 currentCycle = timeElapsed / windowInterval;
        
        // If we're already in a window, return the start of current window
        if (isWindowActive()) {
            return windowStart + (currentCycle * windowInterval);
        }
        
        // Otherwise, return the start of the next window
        return windowStart + ((currentCycle + 1) * windowInterval);
    }

    // Calculate when the current/next window ends
    // Note: This returns the timestamp when the window is no longer active
    // The returned timestamp itself is NOT included in the active window
    function getWindowEndTime() public view returns (uint256) {
        uint256 nextWindowStart = getNextWindowTime();
        return nextWindowStart + windowDuration;
    }

    // Implement beforeSwap hook to restrict trading to allowed windows
    function _beforeSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        if (!isWindowActive()) {
            uint256 nextWindow = getNextWindowTime();
            uint256 windowEnd = nextWindow + windowDuration;
            revert OutsideTradingWindow(block.timestamp, nextWindow, windowEnd);
        }
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    // No ownership or update functions as contract is immutable
}
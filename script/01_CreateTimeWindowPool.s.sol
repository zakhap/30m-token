// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

import {Constants} from "./base/Constants.sol";
import {Config} from "./base/Config.sol";
import {TimeWindowHook} from "../src/TimeWindowHook.sol";

contract CreateTimeWindowPoolScript is Script, Constants, Config {
    using CurrencyLibrary for Currency;

    /////////////////////////////////////
    // --- Parameters to Configure --- //
    /////////////////////////////////////

    // --- pool configuration --- //
    // fees paid by swappers that accrue to liquidity providers
    uint24 lpFee = 3000; // 0.30%
    int24 tickSpacing = 60;

    // starting price of the pool, in sqrtPriceX96
    uint160 startingPrice = 79228162514264337593543950336; // floor(sqrt(1) * 2^96)

    // --- liquidity position configuration --- //
    uint256 public token0Amount =  1e18;                      // 1ETH
    uint256 public token1Amount = 9_989_990_000 * 10**18;        // 0.1001% kept for funding projects

    // range of the position
    int24 tickLower = -600; // must be a multiple of tickSpacing
    int24 tickUpper = 600;

    // Time window hook address (override with env var)
    address public timeWindowHookAddress;
    /////////////////////////////////////

    function setUp() public {
        // Set hook address from environment or use a default
        timeWindowHookAddress = vm.envOr("TIME_WINDOW_HOOK_ADDRESS", address(0));
        if (timeWindowHookAddress == address(0)) {
            console.log("ERROR: Please set TIME_WINDOW_HOOK_ADDRESS environment variable");
            revert("TIME_WINDOW_HOOK_ADDRESS not set");
        }
    }

    function run() external {
        // tokens should be sorted
        PoolKey memory pool = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(timeWindowHookAddress)
        });
        bytes memory hookData = new bytes(0);

        // --------------------------------- //

        // Converts token amounts to liquidity units
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            startingPrice,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            token0Amount,
            token1Amount
        );

        // slippage limits
        uint256 amount0Max = token0Amount + 1 wei;
        uint256 amount1Max = token1Amount + 1 wei;

        (bytes memory actions, bytes[] memory mintParams) =
            _mintLiquidityParams(pool, tickLower, tickUpper, liquidity, amount0Max, amount1Max, msg.sender, hookData);

        // multicall parameters
        bytes[] memory params = new bytes[](2);

        // initialize pool
        params[0] = abi.encodeWithSelector(posm.initializePool.selector, pool, startingPrice, hookData);

        // mint liquidity
        params[1] = abi.encodeWithSelector(
            posm.modifyLiquidities.selector, abi.encode(actions, mintParams), block.timestamp + 60
        );

        // if the pool is an ETH pair, native tokens are to be transferred
        uint256 valueToPass = currency0.isAddressZero() ? amount0Max : 0;

        vm.startBroadcast();
        tokenApprovals();
        vm.stopBroadcast();

        // Print information about the time window hook
        TimeWindowHook hook = TimeWindowHook(timeWindowHookAddress);
        console.log("Creating ETH/TEST pool with TimeWindowHook at:", timeWindowHookAddress);
        console.log("Pool configuration:");
        console.log("  currency0 (ETH):", Currency.unwrap(currency0));
        console.log("  currency1 (TEST):", Currency.unwrap(currency1));
        console.log("  Initial liquidity: %s ETH + %s TEST", token0Amount, token1Amount);
        console.log("Window settings:");
        console.log("  Start:", hook.windowStart());
        console.log("  Duration:", hook.windowDuration(), "seconds");
        console.log("  Interval:", hook.windowInterval(), "seconds");
        
        uint256 nextWindow = hook.getNextWindowTime();
        console.log("Next trading window starts at:", nextWindow);
        console.log("Next trading window ends at:", nextWindow + hook.windowDuration());
        
        // Check ETH balance
        console.log("Deployer ETH balance:", address(msg.sender).balance);
        console.log("Deployer TEST balance:", token1.balanceOf(msg.sender));
        
        // multicall to atomically create pool & add liquidity
        vm.broadcast();
        posm.multicall{value: valueToPass}(params);
    }

    /// @dev helper function for encoding mint liquidity operation
    /// @dev does NOT encode SWEEP, developers should take care when minting liquidity on an ETH pair
    function _mintLiquidityParams(
        PoolKey memory poolKey,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 liquidity,
        uint256 amount0Max,
        uint256 amount1Max,
        address recipient,
        bytes memory hookData
    ) internal pure returns (bytes memory, bytes[] memory) {
        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));

        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(poolKey, _tickLower, _tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData);
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        return (actions, params);
    }

    function tokenApprovals() public {
        // ETH (currency0) doesn't need approval
        if (!currency0.isAddressZero()) {
            token0.approve(address(PERMIT2), type(uint256).max);
            PERMIT2.approve(address(token0), address(posm), type(uint160).max, type(uint48).max);
        }
        // TEST token (currency1) needs approval
        if (!currency1.isAddressZero()) {
            token1.approve(address(PERMIT2), type(uint256).max);
            PERMIT2.approve(address(token1), address(posm), type(uint160).max, type(uint48).max);
        }
    }
}
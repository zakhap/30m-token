// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

import {Constants} from "./base/Constants.sol";
import {TimeWindowHook} from "../src/TimeWindowHook.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

/// @notice Mines the address and deploys the TimeWindowHook.sol contract
contract TimeWindowHookScript is Script, Constants {
    // Window settings (can be overridden with env vars)
    uint256 public windowStart;
    uint256 public windowDuration;
    uint256 public windowInterval;

    function setUp() public {
        // Use environment variables if provided, otherwise use defaults
        windowStart = vm.envOr("WINDOW_START", block.timestamp);
        windowDuration = vm.envOr("WINDOW_DURATION", uint256(1800)); // 30 minutes
        windowInterval = vm.envOr("WINDOW_INTERVAL", uint256(604800)); // 7 days
    }

    function run() public {
        // Hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(
            POOLMANAGER,
            windowStart,
            windowDuration,
            windowInterval
        );
        
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(TimeWindowHook).creationCode,
            constructorArgs
        );

        // Deploy the hook using CREATE2
        vm.broadcast();
        TimeWindowHook hook = new TimeWindowHook{salt: salt}(
            IPoolManager(POOLMANAGER),
            windowStart,
            windowDuration,
            windowInterval
        );
        
        require(address(hook) == hookAddress, "TimeWindowHookScript: hook address mismatch");
        
        console.log("TimeWindowHook deployed at:", address(hook));
        console.log("Window settings:");
        console.log("  Start:", windowStart);
        console.log("  Duration:", windowDuration, "seconds");
        console.log("  Interval:", windowInterval, "seconds");
        
        uint256 nextWindow = hook.getNextWindowTime();
        console.log("Next trading window starts at:", nextWindow);
        console.log("Next trading window ends at:", nextWindow + windowDuration);
    }
}
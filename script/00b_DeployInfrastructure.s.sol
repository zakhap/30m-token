// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IPositionDescriptor} from "v4-periphery/src/interfaces/IPositionDescriptor.sol";
import {IWETH9} from "v4-periphery/src/interfaces/external/IWETH9.sol";
import {DeployPermit2} from "../test/utils/forks/DeployPermit2.sol";

/// @notice Deploys the core Uniswap v4 infrastructure contracts
contract DeployInfrastructureScript is Script, DeployPermit2 {
    function run() public {
        vm.startBroadcast();
        
        // Deploy PoolManager
        IPoolManager poolManager = IPoolManager(address(new PoolManager(address(0))));
        console.log("PoolManager deployed at:", address(poolManager));
        
        // Deploy Permit2 if needed
        anvilPermit2();
        console.log("Permit2 available at:", address(permit2));
        
        // Deploy PositionManager
        IPositionManager positionManager = IPositionManager(
            new PositionManager(
                poolManager, 
                permit2, 
                300_000, 
                IPositionDescriptor(address(0)), 
                IWETH9(address(0))
            )
        );
        console.log("PositionManager deployed at:", address(positionManager));
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("Update Constants.sol with these addresses:");
        console.log("IPoolManager constant POOLMANAGER = IPoolManager(address(%s));", address(poolManager));
        console.log("PositionManager constant posm = PositionManager(payable(address(%s)));", address(positionManager));
        console.log("IAllowanceTransfer constant PERMIT2 = IAllowanceTransfer(address(%s));", address(permit2));
    }
}
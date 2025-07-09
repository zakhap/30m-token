// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/TestToken.sol";

/// @notice Deploys the TestToken contract and mints all tokens to the deployer
contract DeployTestTokenScript is Script {
    function run() public {
        vm.broadcast();
        TestToken token = new TestToken();
        
        console.log("TestToken deployed at:", address(token));
        console.log("Total supply:", token.totalSupply());
        console.log("Deployer balance:", token.balanceOf(msg.sender));
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("");
        console.log("Set this address as TEST_TOKEN_ADDRESS:");
        console.log("export TEST_TOKEN_ADDRESS=%s", address(token));
    }
}
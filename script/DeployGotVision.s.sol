// forge script script/DeployGotVision.s.sol --rpc-url $TESTNET_RPC_URL --broadcast --verify

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {GotVision} from "../src/GotVision.sol";

contract DeployGotVision is Script {
    function setUp() public {}

    function run() public {
        // Retrieve private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Retrieve WLD token address from environment
        address wldTokenAddress = vm.envAddress("WLD_TOKEN_ADDRESS");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy GotVision
        GotVision gotVision = new GotVision(wldTokenAddress);
        
        console.log("GotVision deployed to:", address(gotVision));
        console.log("WLD Token Address:", wldTokenAddress);
        console.log("Owner:", gotVision.owner());

        vm.stopBroadcast();
    }
}
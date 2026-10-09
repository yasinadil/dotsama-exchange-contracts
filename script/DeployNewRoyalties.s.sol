// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RoyaltyFeeManager} from "../src/RoyaltyFeeManager.sol";
import {RoyaltyFeeRegistry} from "../src/RoyaltyFeeRegistry.sol";
import {RoyaltyFeeSetter} from "../src/RoyaltyFeeSetter.sol";

contract DeployNewRoyalties is Script {
    uint256 royaltyLimit = 500;

    function run() external returns (RoyaltyFeeRegistry, RoyaltyFeeSetter, RoyaltyFeeManager) {
        vm.startBroadcast();
        RoyaltyFeeRegistry royaltyFeeRegistry = new RoyaltyFeeRegistry(royaltyLimit);
        RoyaltyFeeSetter royaltyFeeSetter = new RoyaltyFeeSetter(address(royaltyFeeRegistry));
        royaltyFeeRegistry.transferOwnership(address(royaltyFeeSetter));
        RoyaltyFeeManager royaltyFeeManager = new RoyaltyFeeManager(address(royaltyFeeRegistry));
        vm.stopBroadcast();
        return (royaltyFeeRegistry, royaltyFeeSetter, royaltyFeeManager);
    }
}

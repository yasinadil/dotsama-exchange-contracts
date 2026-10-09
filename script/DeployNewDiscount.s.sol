// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DotsamaDiscountPromotions} from "../src/DotsamaDiscountPromotions.sol";

contract DeployNewDiscount is Script {
    address royaltyFeeManager = 0x1A4576CD25B355E475B8C9b170c01B41B81AC6e3;

    function run() external returns (DotsamaDiscountPromotions) {
        vm.startBroadcast();
        DotsamaDiscountPromotions dotsamaDiscountPromotions = new DotsamaDiscountPromotions(royaltyFeeManager);

        vm.stopBroadcast();
        return dotsamaDiscountPromotions;
    }
}

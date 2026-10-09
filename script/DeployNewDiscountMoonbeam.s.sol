// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DotsamaDiscountPromotionsGMLR} from "../src/DotsamaDiscountPromotionsGMLR.sol";

contract DeployNewDiscountGMLR is Script {
    address royaltyFeeManager = 0xe4ec80A1E9Ec1Af25737923CDFb714F06EEa117d;

    function run() external returns (DotsamaDiscountPromotionsGMLR) {
        vm.startBroadcast();
        DotsamaDiscountPromotionsGMLR dotsamaDiscountPromotions = new DotsamaDiscountPromotionsGMLR(royaltyFeeManager);

        vm.stopBroadcast();
        return dotsamaDiscountPromotions;
    }
}

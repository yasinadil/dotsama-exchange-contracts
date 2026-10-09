// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DotsamaBadges} from "../src/DotsamaBadges.sol";
import {DotsamaBadgesStaking} from "../src/DotsamaBadgesStaking.sol";

contract DeployDotsamaBadgesStakingGLMR is Script {
    address _dotsamaExchange = 0xD06598aA3A165a1d50AA1F08d9e62d97e1B1EbfC;
    address _dotsamaBadges = 0xd2d4fC05c53F772F4A48a14Eed9873103d7D0E63;
    address _wrappedAsset = 0xAcc15dC74880C9944775448304B263D191c6077F;
    uint256 _start_time = block.timestamp;

    function run() external returns (DotsamaBadgesStaking) {
        vm.startBroadcast();
        DotsamaBadgesStaking dotsamaBadgesStaking =
            new DotsamaBadgesStaking(_dotsamaExchange, _dotsamaBadges, _wrappedAsset, _start_time);
        vm.stopBroadcast();
        return (dotsamaBadgesStaking);
    }
}

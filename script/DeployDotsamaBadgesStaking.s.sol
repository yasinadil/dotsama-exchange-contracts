// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DotsamaBadges} from "../src/DotsamaBadges.sol";
import {DotsamaBadgesStaking} from "../src/DotsamaBadgesStaking.sol";

contract DeployDotsamaBadgesStaking is Script {
    address _dotsamaExchange = 0xF2bCc85Be129510661A256541Ea7a1C4f6b6892D;
    address _dotsamaBadges = 0x09600Bfb07ad6589728995872A40C5AedC95Ed30;
    address _wrappedAsset = 0xAeaaf0e2c81Af264101B9129C00F4440cCF0F720;
    uint256 _start_time = block.timestamp;

    function run() external returns (DotsamaBadgesStaking) {
        vm.startBroadcast();
        DotsamaBadgesStaking dotsamaBadgesStaking =
            new DotsamaBadgesStaking(_dotsamaExchange, _dotsamaBadges, _wrappedAsset, _start_time);
        vm.stopBroadcast();
        return (dotsamaBadgesStaking);
    }
}

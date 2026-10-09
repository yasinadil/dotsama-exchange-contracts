// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DotsamaBadges} from "../src/DotsamaBadges.sol";
import {DotsamaBadgesStaking} from "../src/DotsamaBadgesStaking.sol";
import {Wrapped} from "../src/WrappedMock.sol";

contract DotsamaBadgesStakingTest is Test {
    DotsamaBadges internal badges;
    DotsamaBadgesStaking internal staking;
    Wrapped internal weth;
    address internal exchange = makeAddr("exchange");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    uint256 internal tokenId;

    function setUp() public {
        badges = new DotsamaBadges();
        weth = new Wrapped(address(this));
        staking = new DotsamaBadgesStaking(exchange, address(badges), address(weth), block.timestamp);

        address[] memory to = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        to[0] = alice;
        amounts[0] = 1;
        badges.aidropMultiple(to, amounts);
        tokenId = badges.totalSupply() == 1 ? 1 : 0;
        vm.prank(alice);
        badges.setApprovalForAll(address(staking), true);
    }

    function _fundEpoch(uint256 amount) internal {
        weth.mint(address(staking), amount);
        uint256 next = staking.getCurrentInterval() + 1;
        vm.prank(exchange);
        staking.updateBalanceAtIntervals(amount, next);
    }

    function test_stakeAndUnstake() public {
        vm.prank(alice);
        staking.stake(tokenId);
        assertEq(badges.ownerOf(tokenId), address(staking));
        assertEq(staking.getStakedTokens(alice).length, 1);

        vm.prank(alice);
        vm.expectRevert("You do not own this NFT"); // custody moved to the staking contract
        staking.stake(tokenId);

        vm.prank(alice);
        staking.unstake(tokenId);
        assertEq(badges.ownerOf(tokenId), alice);
        assertEq(staking.getStakedTokens(alice).length, 0);
    }

    function test_cannotRestakeInSameEpoch() public {
        vm.startPrank(alice);
        staking.stake(tokenId);
        staking.unstake(tokenId);
        vm.expectRevert("You cannot restake the same NFT in the same epoch as you unstaked it.");
        staking.stake(tokenId);
        skip(31 days);
        staking.stake(tokenId);
        vm.stopPrank();
    }

    function test_onlyOwnerOfBadgeCanStakeOrUnstake() public {
        vm.prank(bob);
        vm.expectRevert("You do not own this NFT");
        staking.stake(tokenId);

        vm.prank(alice);
        staking.stake(tokenId);
        vm.prank(bob);
        vm.expectRevert(DotsamaBadgesStaking.User_UnAuthorized.selector);
        staking.unstake(tokenId);
        vm.prank(bob);
        vm.expectRevert(DotsamaBadgesStaking.User_UnAuthorized.selector);
        staking.claimReward(tokenId);
    }

    function test_onlyExchangeFundsEpochs() public {
        vm.prank(alice);
        vm.expectRevert(DotsamaBadgesStaking.User_UnAuthorized.selector);
        staking.updateBalanceAtIntervals(1 ether, 1);
    }

    function test_partialEpochEarnsProRata() public {
        skip(15 days); // stake halfway through epoch 0
        vm.prank(alice);
        staking.stake(tokenId);
        _fundEpoch(10 ether);
        skip(16 days);

        assertApproxEqRel(staking.calculateTokenRewards(tokenId), 5 ether, 0.01e18, "half the epoch, half the pot");
        vm.prank(alice);
        staking.claimReward(tokenId);
        assertApproxEqRel(weth.balanceOf(alice), 5 ether, 0.01e18);
    }

    function test_rewardsAccrueAcrossEpochs() public {
        vm.prank(alice);
        staking.stake(tokenId);
        _fundEpoch(3 ether);
        skip(30 days);
        _fundEpoch(7 ether);
        skip(30 days);
        assertApproxEqAbs(staking.calculateTokenRewards(tokenId), 10 ether, 1e6);
    }

    function test_stakingCanBeClosed() public {
        staking.updateStakeOpenStatus(false);
        vm.prank(alice);
        vm.expectRevert("Staking is closed at the moment. Please try again later.");
        staking.stake(tokenId);
    }
}

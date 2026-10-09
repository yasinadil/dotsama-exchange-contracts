// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {DotsamaExchange} from "../src/Dotsama.sol";
import {CurrencyManager} from "../src/CurrencyManager.sol";
import {ExecutionManager} from "../src/ExecutionManager.sol";
import {StrategyStandardSaleForFixedPrice} from "../src/strategies/StrategyStandardSaleForFixedPrice.sol";
import {RoyaltyFeeRegistry} from "../src/RoyaltyFeeRegistry.sol";
import {RoyaltyFeeManager} from "../src/RoyaltyFeeManager.sol";
import {DotsamaDiscountPromotions} from "../src/DotsamaDiscountPromotions.sol";
import {TransferManagerERC721} from "../src/TransferManagerERC721.sol";
import {TransferManagerERC1155} from "../src/TransferManagerERC1155.sol";
import {TransferSelectorNFT} from "../src/TransferSelector.sol";
import {DotsamaBadges} from "../src/DotsamaBadges.sol";
import {DotsamaBadgesStaking} from "../src/DotsamaBadgesStaking.sol";
import {Wrapped} from "../src/WrappedMock.sol";
import {OrderTypes} from "../src/libraries/OrderTypes.sol";

contract MockNFT is ERC721 {
    constructor() ERC721("Collection", "COL") {}

    function mint(address to, uint256 id) external {
        _mint(to, id);
    }
}

/// @notice End-to-end tests for the marketplace: EIP-712 maker orders matched by takers, with the
///         protocol fee split between the treasury and badge stakers, royalties, and holder discounts.
contract DotsamaExchangeTest is Test {
    DotsamaExchange internal exchange;
    Wrapped internal weth;
    StrategyStandardSaleForFixedPrice internal fixedPrice;
    RoyaltyFeeRegistry internal royaltyRegistry;
    DotsamaBadges internal badges;
    DotsamaBadgesStaking internal staking;
    MockNFT internal nft;

    address internal treasury = makeAddr("treasury");
    address internal artist = makeAddr("artist");
    uint256 internal sellerKey = 0xA11CE;
    uint256 internal buyerKey = 0xB0B;
    address internal seller;
    address internal buyer;

    uint256 internal constant PRICE = 100 ether;
    uint256 internal constant BADGES_CUT = 5000; // 50% of the protocol fee goes to badge stakers

    function setUp() public {
        seller = vm.addr(sellerKey);
        buyer = vm.addr(buyerKey);

        weth = new Wrapped(address(this));
        CurrencyManager currencies = new CurrencyManager();
        currencies.addCurrency(address(weth));
        ExecutionManager executions = new ExecutionManager();
        fixedPrice = new StrategyStandardSaleForFixedPrice();
        executions.addStrategy(address(fixedPrice));
        royaltyRegistry = new RoyaltyFeeRegistry(9500);
        RoyaltyFeeManager royalties = new RoyaltyFeeManager(address(royaltyRegistry));
        DotsamaDiscountPromotions promotions = new DotsamaDiscountPromotions(address(royalties));
        // Partner collections are hard-coded Astar addresses; give them code on the test chain.
        bytes memory nftCode = address(new MockNFT()).code;
        vm.etch(promotions.FORMICA_REGEM(), nftCode);
        vm.etch(promotions.ASTAR_LLAMA(), nftCode);

        exchange = new DotsamaExchange(
            address(currencies),
            address(executions),
            address(royalties),
            address(weth),
            treasury,
            address(promotions),
            BADGES_CUT
        );
        TransferManagerERC721 tm721 = new TransferManagerERC721(address(exchange));
        TransferManagerERC1155 tm1155 = new TransferManagerERC1155(address(exchange));
        exchange.updateTransferSelectorNFT(address(new TransferSelectorNFT(address(tm721), address(tm1155))));

        badges = new DotsamaBadges();
        staking = new DotsamaBadgesStaking(address(exchange), address(badges), address(weth), block.timestamp);
        exchange.updateDotsamaBadges(address(staking));

        nft = new MockNFT();
        nft.mint(seller, 1);
        vm.prank(seller);
        nft.setApprovalForAll(address(tm721), true);

        weth.mint(buyer, 1_000 ether);
        vm.prank(buyer);
        weth.approve(address(exchange), type(uint256).max);
    }

    // ---------------------------------------------------------------- helpers

    function _ask(uint256 nonce, uint256 minPct) internal view returns (OrderTypes.MakerOrder memory o) {
        o = OrderTypes.MakerOrder({
            isOrderAsk: true,
            signer: seller,
            collection: address(nft),
            price: PRICE,
            tokenId: 1,
            amount: 1,
            strategy: address(fixedPrice),
            currency: address(weth),
            nonce: nonce,
            startTime: block.timestamp,
            endTime: block.timestamp + 1 days,
            minPercentageToAsk: minPct,
            params: "",
            v: 0,
            r: 0,
            s: 0
        });
        _sign(o, sellerKey);
    }

    function _sign(OrderTypes.MakerOrder memory o, uint256 key) internal view {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("DotsamaNFTMarketplace"),
                keccak256("1"),
                block.chainid,
                address(exchange)
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domain, _hash(o)));
        (o.v, o.r, o.s) = vm.sign(key, digest);
    }

    function _hash(OrderTypes.MakerOrder memory o) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                OrderTypes.MAKER_ORDER_HASH,
                o.isOrderAsk,
                o.signer,
                o.collection,
                o.price,
                o.tokenId,
                o.amount,
                o.strategy,
                o.currency,
                o.nonce,
                o.startTime,
                o.endTime,
                o.minPercentageToAsk,
                keccak256(o.params)
            )
        );
    }

    function _bid() internal view returns (OrderTypes.TakerOrder memory) {
        return OrderTypes.TakerOrder({
            isOrderAsk: false, taker: buyer, price: PRICE, tokenId: 1, minPercentageToAsk: 0, params: ""
        });
    }

    function _buy(OrderTypes.MakerOrder memory ask) internal {
        vm.prank(buyer);
        exchange.matchAskWithTakerBid(_bid(), ask);
    }

    function _setRoyalty(uint256 bps) internal {
        royaltyRegistry.updateRoyaltyInfoForCollection(address(nft), address(this), artist, bps);
    }

    // ---------------------------------------------------------------- settlement

    function test_feeSplitWithoutRoyalty() public {
        _buy(_ask(0, 9000));

        assertEq(nft.ownerOf(1), buyer);
        assertEq(weth.balanceOf(seller), 97 ether, "seller: price minus 3% protocol fee");
        assertEq(weth.balanceOf(treasury), 1.5 ether, "treasury keeps half the fee");
        assertEq(weth.balanceOf(address(staking)), 1.5 ether, "badge stakers get the other half");
        assertEq(staking.getBalanceAtIntervals(1), 1.5 ether, "booked to the next epoch");
    }

    function test_royaltyPaid() public {
        _setRoyalty(500);
        _buy(_ask(0, 9000));
        assertEq(weth.balanceOf(artist), 5 ether);
        assertEq(weth.balanceOf(seller), 92 ether);
    }

    function test_partnerHolderDiscount() public {
        // Sellers holding the partner collection pay 1% less protocol fee; that 1% is redirected
        // from royalties to badge stakers.
        address partner = DotsamaDiscountPromotions(address(exchange.dotsamaDiscountPromotions())).FORMICA_REGEM();
        MockNFT(partner).mint(seller, 7);
        _setRoyalty(500);

        _buy(_ask(0, 9000));
        assertEq(weth.balanceOf(seller), 93 ether, "100 - 2% fee - 5% royalty");
        assertEq(weth.balanceOf(artist), 4 ether, "royalty minus the 1% redirected");
        assertEq(weth.balanceOf(treasury), 1 ether);
        assertEq(weth.balanceOf(address(staking)), 2 ether, "half of 2% fee + 1% from royalty");
        assertEq(
            weth.balanceOf(seller) + weth.balanceOf(artist) + weth.balanceOf(treasury)
                + weth.balanceOf(address(staking)),
            PRICE,
            "every wei accounted for"
        );
    }

    function test_makerBidMatchedByTakerAsk() public {
        OrderTypes.MakerOrder memory bid = _ask(0, 9000);
        bid.isOrderAsk = false;
        bid.signer = buyer;
        _sign(bid, buyerKey);

        OrderTypes.TakerOrder memory ask = OrderTypes.TakerOrder({
            isOrderAsk: true, taker: seller, price: PRICE, tokenId: 1, minPercentageToAsk: 9000, params: ""
        });
        vm.prank(seller);
        exchange.matchBidWithTakerAsk(ask, bid);
        assertEq(nft.ownerOf(1), buyer);
        assertEq(weth.balanceOf(seller), 97 ether);
    }

    // ---------------------------------------------------------------- order safety

    function test_orderCannotBeReplayed() public {
        OrderTypes.MakerOrder memory ask = _ask(0, 9000);
        _buy(ask);
        vm.prank(buyer);
        vm.expectRevert("Order: Matching order expired");
        exchange.matchAskWithTakerBid(_bid(), ask);
    }

    function test_cancelAllOrdersInvalidatesLowerNonces() public {
        OrderTypes.MakerOrder memory ask = _ask(3, 9000);
        vm.prank(seller);
        exchange.cancelAllOrdersForSender(5);
        vm.prank(buyer);
        vm.expectRevert("Order: Matching order expired");
        exchange.matchAskWithTakerBid(_bid(), ask);
    }

    function test_cancelSpecificNonce() public {
        OrderTypes.MakerOrder memory ask = _ask(9, 9000);
        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 9;
        vm.prank(seller);
        exchange.cancelMultipleMakerOrders(nonces);
        vm.prank(buyer);
        vm.expectRevert("Order: Matching order expired");
        exchange.matchAskWithTakerBid(_bid(), ask);
    }

    function test_rejectsForgedSignature() public {
        OrderTypes.MakerOrder memory ask = _ask(0, 9000);
        _sign(ask, buyerKey); // signed by someone other than `signer`
        vm.prank(buyer);
        vm.expectRevert("Signature: Invalid");
        exchange.matchAskWithTakerBid(_bid(), ask);
    }

    function test_rejectsTamperedPrice() public {
        OrderTypes.MakerOrder memory ask = _ask(0, 9000);
        ask.price = 1 ether; // signature no longer matches
        OrderTypes.TakerOrder memory bid = _bid();
        bid.price = 1 ether;
        vm.prank(buyer);
        vm.expectRevert("Signature: Invalid");
        exchange.matchAskWithTakerBid(bid, ask);
    }

    function test_sellerSlippageProtection() public {
        _setRoyalty(500); // seller would receive 92%
        OrderTypes.MakerOrder memory ask = _ask(0, 9500); // but requires at least 95%
        vm.prank(buyer);
        vm.expectRevert("Fees: Higher than expected");
        exchange.matchAskWithTakerBid(_bid(), ask);
    }

    function test_takerMustBeSender() public {
        OrderTypes.MakerOrder memory ask = _ask(0, 9000);
        vm.prank(makeAddr("relayer"));
        vm.expectRevert("Order: Taker must be the sender");
        exchange.matchAskWithTakerBid(_bid(), ask);
    }

    // ---------------------------------------------------------------- staker rewards

    function test_stakersEarnTradingFeesForTheEpoch() public {
        address[] memory to = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        (to[0], to[1]) = (makeAddr("staker1"), makeAddr("staker2"));
        (amounts[0], amounts[1]) = (1, 1);
        badges.aidropMultiple(to, amounts);
        uint256 first = badges.totalSupply() == 2 ? 1 : 0;

        for (uint256 i; i < 2; i++) {
            vm.startPrank(to[i]);
            badges.approve(address(staking), first + i);
            staking.stake(first + i);
            vm.stopPrank();
        }

        _buy(_ask(0, 9000)); // 1.5 WETH to stakers, booked to epoch 1
        skip(31 days); // epoch 0 complete
        _setRoyalty(0);

        uint256 expected = staking.calculateTokenRewards(first);
        assertApproxEqAbs(expected, 0.75 ether, 0.01 ether, "two stakers split 1.5 WETH");
        vm.prank(to[0]);
        staking.claimReward(first);
        assertEq(weth.balanceOf(to[0]), expected);

        vm.prank(to[0]);
        vm.expectRevert("Cannot claim zero rewards. Please wait for current epoch to end.");
        staking.claimReward(first);
    }
}

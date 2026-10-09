// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DotsamaExchange} from "../src/Dotsama.sol";
import {CurrencyManager} from "../src/CurrencyManager.sol";
import {ExecutionManager} from "../src/ExecutionManager.sol";
import {RoyaltyFeeManager} from "../src/RoyaltyFeeManager.sol";
import {RoyaltyFeeRegistry} from "../src/RoyaltyFeeRegistry.sol";
import {RoyaltyFeeSetter} from "../src/RoyaltyFeeSetter.sol";
import {DotsamaDiscountPromotions} from "../src/DotsamaDiscountPromotions.sol";
import {TransferSelectorNFT} from "../src/TransferSelector.sol";
import {TransferManagerERC721} from "../src/TransferManagerERC721.sol";
import {TransferManagerERC1155} from "../src/TransferManagerERC1155.sol";
import {StrategyDutchAuction} from "../src/strategies/StrategyDutchAuction.sol";
import {StrategyStandardSaleForFixedPrice} from "../src/strategies/StrategyStandardSaleForFixedPrice.sol";
import {DotsamaBadgesStaking} from "../src/DotsamaBadgesStaking.sol";

contract DeployDotsama is Script {
    // Counter public counter;

    // function setUp() public {}
    uint256 royaltyLimit = 1000;
    address WASTR = 0xAeaaf0e2c81Af264101B9129C00F4440cCF0F720;
    address protocolFeeRecipient = 0xdF030553D3134486E39F4082ABebe4950eAB53F5;
    uint256 dotsamaBadgesFeeCut = 5000;
    uint256 minimumAuctionLengthInSeconds = 14400;
    uint256 protocolFees = 300;
    address dotsamaBadges = 0x09600Bfb07ad6589728995872A40C5AedC95Ed30;

    function run() external returns (DotsamaExchange) {
        vm.startBroadcast();
        CurrencyManager currencyManager = new CurrencyManager();
        currencyManager.addCurrency(WASTR);
        // add currency
        ExecutionManager executionManager = new ExecutionManager();
        // add strategies
        StrategyDutchAuction strategyDutchAuction =
            new StrategyDutchAuction(protocolFees, minimumAuctionLengthInSeconds);
        StrategyStandardSaleForFixedPrice strategyStandardSaleForFixedPrice = new StrategyStandardSaleForFixedPrice();
        executionManager.addStrategy(address(strategyDutchAuction));
        executionManager.addStrategy(address(strategyStandardSaleForFixedPrice));

        RoyaltyFeeRegistry royaltyFeeRegistry = new RoyaltyFeeRegistry(royaltyLimit);
        RoyaltyFeeSetter royaltyFeeSetter = new RoyaltyFeeSetter(address(royaltyFeeRegistry));
        royaltyFeeRegistry.transferOwnership(address(royaltyFeeSetter));
        royaltyFeeSetter.transferOwnership(address(royaltyFeeRegistry));
        RoyaltyFeeManager royaltyFeeManager = new RoyaltyFeeManager(address(royaltyFeeRegistry));

        DotsamaDiscountPromotions dotsamaDiscountPromotions = new DotsamaDiscountPromotions(address(royaltyFeeManager));
        DotsamaExchange dotsamaExchange = new DotsamaExchange(
            address(currencyManager),
            address(executionManager),
            address(royaltyFeeManager),
            WASTR,
            protocolFeeRecipient,
            address(dotsamaDiscountPromotions),
            dotsamaBadgesFeeCut
        );
        TransferManagerERC721 transferManagerERC721 = new TransferManagerERC721(address(dotsamaExchange));
        TransferManagerERC1155 transferManagerERC1155 = new TransferManagerERC1155(address(dotsamaExchange));
        TransferSelectorNFT transferSelectorNFT =
            new TransferSelectorNFT(address(transferManagerERC721), address(transferManagerERC1155));
        dotsamaExchange.updateTransferSelectorNFT(address(transferSelectorNFT));

        DotsamaBadgesStaking dotsamaBadgesStaking =
            new DotsamaBadgesStaking(address(dotsamaExchange), dotsamaBadges, WASTR, block.timestamp);

        vm.stopBroadcast();
        console.log("currencyManager", address(currencyManager));
        console.log("executionManager", address(executionManager));
        console.log("strategyDutchAuction", address(strategyDutchAuction));
        console.log("strategyStandardSaleForFixedPrice", address(strategyStandardSaleForFixedPrice));
        console.log("royaltyFeeRegistry", address(royaltyFeeRegistry));
        console.log("royaltyFeeSetter", address(royaltyFeeSetter));
        console.log("royaltyFeeManager", address(royaltyFeeManager));
        console.log("dotsamaDiscountPromotions", address(dotsamaDiscountPromotions));
        console.log("dotsamaExchange", address(dotsamaExchange));
        console.log("transferManagerERC721", address(transferManagerERC721));
        console.log("transferManagerERC1155", address(transferManagerERC1155));
        console.log("transferSelectorNFT", address(transferSelectorNFT));
        console.log("dotsamaBadgesStaking", address(dotsamaBadgesStaking));

        return dotsamaExchange;
    }
}

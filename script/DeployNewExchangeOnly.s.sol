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

contract DeployNewExchangeOnly is Script {
    // Counter public counter;

    // function setUp() public {}
    address WASTR = 0xAeaaf0e2c81Af264101B9129C00F4440cCF0F720;
    address protocolFeeRecipient = 0xdF030553D3134486E39F4082ABebe4950eAB53F5;
    uint256 dotsamaBadgesFeeCut = 5000;
    address currencyManager = 0x795c4BBfBCB33ce95949bC089F366F85FCAF67a9;
    address executionManager = 0xaF6E6B9AFb081c8DFCF01B108a1395fb584F0018;
    address royaltyFeeManager = 0x188D6Ca31441bE3b6eEE271DdBC7BF8DF47F1DD9;
    address dotsamaDiscountPromotions = 0x6A134542C8fb10c9CeA3c9c3ebdC163B968AF0e7;
    address dotsamaExchangeAddr = 0x95cC5C60ce9F26420b5679D2C6280E90028796a1;

    function run() external returns (TransferSelectorNFT) {
        vm.startBroadcast();

        // DotsamaExchange dotsamaExchange = new DotsamaExchange(currencyManager,executionManager,royaltyFeeManager,WASTR,protocolFeeRecipient,dotsamaDiscountPromotions,dotsamaBadgesFeeCut);
        // DotsamaExchange dotsamaExchange = new DotsamaExchange(dotsamaExchangeAddr);
        TransferManagerERC721 transferManagerERC721 = new TransferManagerERC721(dotsamaExchangeAddr);
        TransferManagerERC1155 transferManagerERC1155 = new TransferManagerERC1155(dotsamaExchangeAddr);
        TransferSelectorNFT transferSelectorNFT =
            new TransferSelectorNFT(address(transferManagerERC721), address(transferManagerERC1155));
        // dotsamaExchange.updateTransferSelectorNFT(address(transferSelectorNFT));
        vm.stopBroadcast();

        return transferSelectorNFT;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OrderTypes} from "../libraries/OrderTypes.sol";

interface IDotsamaExchange {
    function matchAskWithTakerBidUsingETHAndWETH(
        OrderTypes.TakerOrder[] calldata takerBid,
        OrderTypes.MakerOrder[] calldata makerAsk
    ) external payable;

    function matchAskWithTakerBid(OrderTypes.TakerOrder calldata takerBid, OrderTypes.MakerOrder calldata makerAsk)
        external;

    function matchBidWithTakerAsk(OrderTypes.TakerOrder calldata takerAsk, OrderTypes.MakerOrder calldata makerBid)
        external;
}

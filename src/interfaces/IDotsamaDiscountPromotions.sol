// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDotsamaDiscountPromotions {
    function _calculateProtocolFee(address executionStrategy, address collection, address user, uint256 amount)
        external
        view
        returns (uint256, uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDotsamaBadgesStaking {
    function updateBalanceAtIntervals(uint256 _balance, uint256 _interval) external;
    function getCurrentInterval() external view returns (uint256);
    function getBalanceAtIntervals(uint256 _interval) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITransferSelectorNFT {
    function checkTransferManagerForToken(address collection) external view returns (address);
}

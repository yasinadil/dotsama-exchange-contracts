// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {ITransferManagerNFT} from "./interfaces/ITransferManagerNFT.sol";

/**
 * @title TransferManagerERC721
 * @notice It allows the transfer of ERC721 tokens.
 */
contract TransferManagerERC721 is ITransferManagerNFT {
    address public immutable DOTSAMA_EXCHANGE;

    /**
     * @notice Constructor
     * @param _dotsamaExchange address of the Dotsama exchange
     */
    constructor(address _dotsamaExchange) {
        DOTSAMA_EXCHANGE = _dotsamaExchange;
    }

    /**
     * @notice Transfer ERC721 token
     * @param collection address of the collection
     * @param from address of the sender
     * @param to address of the recipient
     * @param tokenId tokenId
     * @dev For ERC721, amount is not used
     */
    function transferNonFungibleToken(address collection, address from, address to, uint256 tokenId, uint256)
        external
        override
    {
        require(msg.sender == DOTSAMA_EXCHANGE, "Transfer: Only Dotsama Exchange");
        // https://docs.openzeppelin.com/contracts/2.x/api/token/erc721#IERC721-safeTransferFrom
        IERC721(collection).safeTransferFrom(from, to, tokenId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "ERC721A/ERC721A.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DotsamaBadges is ERC721A, Ownable {
    error SoldOut();
    error InvalidAmount();
    error InsufficientEther();
    error MintClosed();
    uint256 public constant MAX_SUPPLY = 5000;
    uint256 public cost;
    uint256 public mintMAX = 3;
    string public baseURI;
    bool public mintOpen = false;

    mapping(address => uint256) public mintedByUSER;

    constructor() ERC721A("Dotsama Badges", "DSB") Ownable(msg.sender) {}

    function mint(uint256 _amount) external payable {
        require(mintedByUSER[msg.sender] + _amount <= mintMAX, "MAX MINT LIMIT REACHED!");

        if (!mintOpen) {
            revert MintClosed();
        }

        if (totalSupply() + _amount > MAX_SUPPLY) {
            revert SoldOut();
        }

        if (_amount <= 0) {
            revert InvalidAmount();
        }

        if (msg.value < _amount * cost) {
            revert InsufficientEther();
        }

        mintedByUSER[msg.sender] += _amount;
        _safeMint(msg.sender, _amount);
    }

    /**
     * @dev Aidrop tokens to users
     */
    function aidropMultiple(address[] memory recipients, uint256[] memory _amounts) external onlyOwner {
        for (uint256 i = 0; i < recipients.length; i++) {
            _safeMint(recipients[i], _amounts[i]);
        }
    }

    /**
     * @dev Returns the starting token ID for sequential mints.
     *
     * Override this function to change the starting token ID for sequential mints.
     *
     * Note: The value returned must never change after any tokens have been minted.
     */
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    /**
     * @dev Returns the token URL for a tokenId.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Err: ERC721AMetadata - URI query for nonexistent token");

        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, _toString(tokenId), ".json")) : "";
    }

    /**
     * @dev Withdraw function for the owner of the smart contract.
     *
     * Note: Only Native currency of the chain can be withdrawn.
     */
    function withdraw() public payable onlyOwner {
        // =============================================================================
        (bool os,) = payable(owner()).call{value: address(this).balance}("");
        require(os);
        // =============================================================================
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setMintLimit(uint256 _limit) public onlyOwner {
        mintMAX = _limit;
    }

    function setMintCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function setMintStatus(bool _status) public onlyOwner {
        mintOpen = _status;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./interfaces/IExecutionStrategy.sol";
import "./interfaces/IRoyaltyFeeManager.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract DotsamaDiscountPromotionsGMLR {
    address public constant MOONBEAM_LLAMA = 0x9f4B77eCC72dF6D7b2a141D2A92391a866b969aa;
    address public constant FORMICA_REGEM = 0x57b2788C23f02628e9FD8092E50608390F517E45;
    IRoyaltyFeeManager public royaltyFeeManager;

    constructor(address _royaltyFeeManager) {
        royaltyFeeManager = IRoyaltyFeeManager(_royaltyFeeManager);
    }

    /**
     * @notice Calculate protocol fee for an execution strategy
     * @param executionStrategy strategy
     * @param amount amount to transfer
     */
    function _calculateProtocolFee(address executionStrategy, address collection, address user, uint256 amount)
        external
        view
        returns (uint256, uint256)
    {
        uint256 protocolFee = IExecutionStrategy(executionStrategy).viewProtocolFee();

        uint256 dotsamaBadgesFee = discountEligibility(user, collection);
        uint256 royaltyDeduction;
        if (dotsamaBadgesFee > 0) {
            protocolFee -= dotsamaBadgesFee;
            royaltyDeduction = (dotsamaBadgesFee * amount) / 10000;
        }
        return ((protocolFee * amount) / 10000, royaltyDeduction);
    }

    function discountEligibility(address user, address collection) public view returns (uint256) {
        (, uint256 royaltyFeeAmount) = royaltyFeeManager.calculateRoyaltyFeeAndGetRecipient(collection, 1, 1 ether);
        if (royaltyFeeAmount == 0) {
            return 0;
        }
        uint256 royaltyPerc = (royaltyFeeAmount * 10000) / 1 ether;
        if (IERC721(FORMICA_REGEM).balanceOf(user) > 0 && royaltyPerc >= 100) {
            return 100;
        } else if (IERC721(MOONBEAM_LLAMA).balanceOf(user) > 0 && royaltyPerc >= 50) {
            return 50;
        } else {
            return 0;
        }
    }
}

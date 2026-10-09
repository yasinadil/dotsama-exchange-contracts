// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DotsamaBadgesStaking is IERC721Receiver, Ownable {
    // Start time for the staking mechanism to begin the reward distribution algorithm
    uint256 public START_TIME;

    // Reward distribution duration
    uint256 public EPOCH_DURATION = 30 days;

    // Number of total tokens staked
    uint256 public stakedNFTs;

    // Constant for normalization of decimal units
    uint256 private MULTIPLIER = 1e18;

    // Smart Contract Address for Dotsama NFT Marketplace
    address public DotsamaExchange;

    bool public stakeOpen = true;

    // Dotsama Badges Collection
    IERC721 public dotsamaBadges;

    // Native Wrapped Asset
    IERC20 public WrappedAsset;

    struct token {
        uint256 stakedAt;
        uint256 unstakedAt;
        bool staked;
    }

    struct interval {
        uint256 balance;
        uint256 stakedNFTs;
    }

    mapping(uint256 => interval) public balanceAtIntervals;
    mapping(address => uint256[]) public stakedTokensByUser;
    mapping(uint256 => token) public stakedTokenInfo;
    mapping(uint256 => uint256) public lastClaim;

    constructor(address _dotsamaExchange, address _dotsamaBadges, address _wrappedAsset, uint256 _start_time)
        Ownable(msg.sender)
    {
        DotsamaExchange = _dotsamaExchange;
        dotsamaBadges = IERC721(_dotsamaBadges);
        WrappedAsset = IERC20(_wrappedAsset);
        START_TIME = _start_time;
    }

    error Token_Already_Staked();
    error User_UnAuthorized();

    event StakedNFT(uint256 tokenId, address stakedBy);
    event UnstakedNFT(uint256 tokenId, address stakedBy);
    event ClaimedReward(uint256 tokenId, address claimedBy, uint256 claimedReward);

    // Stake an NFT
    function stake(uint256 _tokenId) external {
        require(stakeOpen, "Staking is closed at the moment. Please try again later.");
        require(dotsamaBadges.ownerOf(_tokenId) == msg.sender, "You do not own this NFT");

        uint256[] memory tokens = getStakedTokens(msg.sender);
        uint256 currEpoch = getCurrentInterval();
        bool staked;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (_tokenId == tokens[i]) {
                staked = true;
            }
        }
        if (staked) {
            revert Token_Already_Staked();
        } else {
            stakedTokensByUser[msg.sender].push(_tokenId);
            token storage stakedToken = stakedTokenInfo[_tokenId];

            if (stakedToken.unstakedAt != 0) {
                uint256 unstakedEpoch = (stakedToken.unstakedAt - START_TIME) / EPOCH_DURATION;
                require(
                    unstakedEpoch != currEpoch, "You cannot restake the same NFT in the same epoch as you unstaked it."
                );
            }

            stakedToken.stakedAt = block.timestamp;
            stakedToken.unstakedAt = 0;
            stakedToken.staked = true;
        }
        stakedNFTs = stakedNFTs + 1;
        balanceAtIntervals[currEpoch + 1].stakedNFTs = stakedNFTs;
        dotsamaBadges.transferFrom(msg.sender, address(this), _tokenId);

        emit StakedNFT(_tokenId, msg.sender);
    }

    // Unstake an NFT
    function unstake(uint256 _tokenId) external {
        bool staked = stakedByUser(msg.sender, _tokenId);
        if (staked) {
            stakedNFTs = stakedNFTs - 1;
            token storage stakedToken = stakedTokenInfo[_tokenId];
            stakedToken.staked = false;
            stakedToken.stakedAt = 0;
            stakedToken.unstakedAt = block.timestamp;
            lastClaim[_tokenId] = 0;
            removeStakedToken(msg.sender, _tokenId);
            dotsamaBadges.transferFrom(address(this), msg.sender, _tokenId);
        } else {
            revert User_UnAuthorized();
        }

        emit UnstakedNFT(_tokenId, msg.sender);
    }

    // claim reward
    function claimReward(uint256 _tokenId) external {
        bool staked = stakedByUser(msg.sender, _tokenId);
        if (!staked) {
            revert User_UnAuthorized();
        }

        uint256 totalRewards = calculateTokenRewards(_tokenId);
        lastClaim[_tokenId] = START_TIME + (getCurrentInterval() * EPOCH_DURATION);
        require(totalRewards > 0, "Cannot claim zero rewards. Please wait for current epoch to end.");
        WrappedAsset.transfer(msg.sender, totalRewards);
        emit ClaimedReward(_tokenId, msg.sender, totalRewards);
    }

    function calculateTokenRewards(uint256 _tokenId) public view returns (uint256) {
        // Get the staked information of the NFT
        token memory stakedInfo = stakedTokenInfo[_tokenId];
        uint256 stakedTime = lastClaim[_tokenId] > 0 ? lastClaim[_tokenId] : stakedInfo.stakedAt;

        uint256 unstakedAt = stakedInfo.unstakedAt;

        // Calculate current epoch based on current time
        uint256 currentEpoch = (block.timestamp - START_TIME) / EPOCH_DURATION;

        // Initialize total rewards
        uint256 totalRewards = 0;

        // Loop through intervals to calculate rewards
        for (uint256 epochIndex = 1; epochIndex <= currentEpoch; epochIndex++) {
            // Get the balance at the end of the epoch
            interval memory intervalDetail = getStatsAtIntervals(epochIndex);

            // Determine the time staked in this epoch
            uint256 timeStakedInEpoch = calculateTimeStaked(stakedTime, unstakedAt, epochIndex - 1);

            if (timeStakedInEpoch > 0) {
                // Calculate rewards for this interval

                uint256 rewards = (intervalDetail.balance > 0 && intervalDetail.stakedNFTs > 0)
                    ? (((intervalDetail.balance / intervalDetail.stakedNFTs) * timeStakedInEpoch) / MULTIPLIER)
                    : 0;

                totalRewards += rewards;
            }
        }

        return totalRewards;
    }

    function calculateTotalRewards() public view returns (uint256) {
        uint256[] memory allStakedNFTs = getStakedTokens(msg.sender);
        uint256 totalRewards;
        if (allStakedNFTs.length > 0) {
            for (uint256 i = 0; i < allStakedNFTs.length; i++) {
                totalRewards += calculateTokenRewards(allStakedNFTs[i]);
            }
        }
        return totalRewards;
    }

    function nextEpochEndTime() external view returns (uint256) {
        uint256 epochEndTime = (START_TIME + (getCurrentInterval() * EPOCH_DURATION)) + EPOCH_DURATION;
        return epochEndTime;
    }

    function calculateTimeStaked(uint256 _stakedAt, uint256 _unstakedAt, uint256 _epochIndex)
        public
        view
        returns (uint256)
    {
        uint256 epochStartTime = START_TIME + (_epochIndex * EPOCH_DURATION);
        uint256 epochEndTime = epochStartTime + EPOCH_DURATION;
        if (
            (_epochIndex >= getCurrentInterval()) || (_unstakedAt != 0 && _unstakedAt < epochStartTime)
                || (epochEndTime < _stakedAt)
        ) {
            return 0;
        }
        // Calculate time staked in this epoch
        uint256 stakedTimeInEpoch =
            (_unstakedAt != 0 ? min(_unstakedAt, epochEndTime) : epochEndTime) - max(_stakedAt, epochStartTime);
        return (stakedTimeInEpoch * MULTIPLIER) / EPOCH_DURATION; // normalize to epoch units
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // Function to remove a token from a user's staked tokens
    function removeStakedToken(address _user, uint256 _tokenId) internal {
        uint256[] storage userTokens = stakedTokensByUser[_user];
        uint256 indexToRemove = userTokens.length;

        // Find the index of the token to remove
        for (uint256 i = 0; i < userTokens.length; i++) {
            if (userTokens[i] == _tokenId) {
                indexToRemove = i;
                break;
            }
        }

        // Ensure the token was found
        require(indexToRemove < userTokens.length, "Token not found");

        // Move the last element into the place of the element to delete
        userTokens[indexToRemove] = userTokens[userTokens.length - 1];

        // Remove the last element
        userTokens.pop();
    }

    // Function to get staked tokenIds for a specific address
    function getStakedTokens(address user) public view returns (uint256[] memory) {
        return stakedTokensByUser[user];
    }

    // Function to get staked tokenIds for a specific address
    function getAmountOfStakerNFTsByUser(address _user) public view returns (uint256) {
        return stakedTokensByUser[_user].length;
    }

    function getBalanceAtIntervals(uint256 _interval) public view returns (uint256) {
        return balanceAtIntervals[_interval].balance;
    }

    function getStakedNFTsAtIntervals(uint256 _interval) public view returns (uint256) {
        return balanceAtIntervals[_interval].stakedNFTs;
    }

    function getStatsAtIntervals(uint256 _interval) public view returns (interval memory) {
        return balanceAtIntervals[_interval];
    }

    function getCurrentInterval() public view returns (uint256) {
        return (block.timestamp - START_TIME) / EPOCH_DURATION;
    }

    function getStakedInfoOfTokenId(uint256 _tokenId) public view returns (token memory) {
        token memory stakedInfo = stakedTokenInfo[_tokenId];
        return stakedInfo;
    }

    function stakedByUser(address _user, uint256 _tokenId) public view returns (bool) {
        uint256[] memory tokens = getStakedTokens(_user);
        bool staked;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (stakedTokensByUser[_user][i] == _tokenId) {
                staked = true;
                break;
            }
        }

        return staked;
    }

    function updateBalanceAtIntervals(uint256 _balance, uint256 _interval) external {
        if (msg.sender != DotsamaExchange) {
            revert User_UnAuthorized();
        }
        balanceAtIntervals[_interval].balance += _balance;
        balanceAtIntervals[_interval].stakedNFTs = stakedNFTs;
    }

    function updateDotsamaBadges(address _dotsamaBadges) external onlyOwner {
        dotsamaBadges = IERC721(_dotsamaBadges);
    }

    function updateStartTime(uint256 _startTime) external onlyOwner {
        START_TIME = _startTime;
    }

    function updateDotsamaExchange(address _dotsamaExchange) external onlyOwner {
        DotsamaExchange = _dotsamaExchange;
    }

    function updateStakeOpenStatus(bool _status) external onlyOwner {
        stakeOpen = _status;
    }

    /**
     * @dev Withdraw function for the owner of the smart contract.
     *
     * Note: Only Native currency of the chain can be withdrawn.
     */
    function withdrawEmergency() public payable onlyOwner {
        // =============================================================================
        (bool os,) = payable(owner()).call{value: address(this).balance}("");
        require(os);
        // =============================================================================
    }

    /**
     * @dev Withdraw function for the owner of the smart contract.
     *
     * Note: Only ERC20 currency of the chain can be withdrawn.
     */
    function withdrawERC20Emergency(address _tokenAddress, uint256 _value) public onlyOwner {
        // =============================================================================
        IERC20(_tokenAddress).transfer(msg.sender, _value);
        // =============================================================================
    }

    function onERC721Received(address, address from, uint256, bytes calldata) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send NFTs to Vault directly");
        return IERC721Receiver.onERC721Received.selector;
    }

    // Function to receive Ether
    receive() external payable {}
}

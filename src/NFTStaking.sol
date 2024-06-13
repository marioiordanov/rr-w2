// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;
import {NFT} from "./NFT.sol";
import {ERC20Reward} from "./ERC20Reward.sol";
import {IERC721Receiver} from "@openzeppelin/contracts@v5.0.2/token/ERC721/IERC721Receiver.sol";

/// @title Staking contract. Stake your NFT and receive reward in ERC20 token
/// @author marioiordanov
/// @notice You send your nft to the contract and wait for 24 hours to receive reward. Every 24 hours you receive reward.
/// @notice Claiming is done per token. You can claim reward for a specific token or withdraw the token and the reward
contract NFTStaking is IERC721Receiver {
    // type declarations
    struct NftDepositInfo {
        uint96 depositTimestamp;
        address owner;
    }

    // constants
    uint256 public constant TIME_TO_REWARD = 24 hours;
    uint256 public constant REWARD_AMOUNT_WITHOUT_DECIMALS = 10;

    // state vars
    ERC20Reward public immutable i_rewardToken;
    NFT private immutable i_nft;

    mapping(uint256 tokenId => NftDepositInfo depositInfo) public s_nftOwners;
    mapping(uint256 tokenId => uint256 rewardPerToken) private s_nftRewardTally;

    // events
    event NftWithdrawn(uint256 tokenId, address owner);
    event RewardWithdrawn(uint256 tokenId, address owner);

    // errors
    error UnsupportedNftToken();
    error NotTheOwner();

    // modifiers
    modifier onlyNftOwner(uint256 tokenId) {
        if (s_nftOwners[tokenId].owner != msg.sender) {
            revert NotTheOwner();
        }
        _;
    }

    // functions
    constructor(NFT _nft) {
        i_nft = _nft;
        i_rewardToken = new ERC20Reward();
    }

    /// @notice Call this function to withdraw your NFT from the contract
    /// @dev After withdrawing the NFT, If there is reward it will be send to the owner of the nft
    /// @dev Storage is deleted for the NFT and the reward tally
    /// @param tokenId The id of the NFT to withdraw
    function withdrawNFt(uint256 tokenId) external onlyNftOwner(tokenId) {
        uint256 rewardAmount = _getRewardAmount(tokenId);
        delete s_nftOwners[tokenId];
        if (rewardAmount > 0) {
            delete s_nftRewardTally[tokenId];
            emit RewardWithdrawn(tokenId, msg.sender);
            i_rewardToken.mint(msg.sender, rewardAmount);
        }

        emit NftWithdrawn(tokenId, msg.sender);
        // notify receiver, in the case it is smart contract
        i_nft.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    /// @notice Withdraws accumulated reward for a given NFT
    /// @dev Explain to a developer any extra details
    /// @param tokenId The NFT id for which the reward will be withdrawn
    /// @return Returns the amount of reward.
    function claimReward(
        uint256 tokenId
    ) external onlyNftOwner(tokenId) returns (uint256) {
        uint256 rewardAmount = _getRewardAmount(tokenId);
        if (rewardAmount > 0) {
            s_nftRewardTally[tokenId] += rewardAmount;
            emit RewardWithdrawn(tokenId, msg.sender);
            i_rewardToken.mint(msg.sender, rewardAmount);
        }

        return rewardAmount;
    }

    function onERC721Received(
        address /*operator*/,
        address from,
        uint256 tokenId,
        bytes calldata /*data*/
    ) external override returns (bytes4) {
        if (msg.sender != address(i_nft)) {
            revert UnsupportedNftToken();
        }
        s_nftOwners[tokenId] = NftDepositInfo({
            owner: from,
            depositTimestamp: uint96(block.timestamp)
        });
        return type(IERC721Receiver).interfaceId;
    }

    /// @notice Returns the reward amount available for withdrawal for a given NFT
    /// @dev Calculates the total accumulated reward for a given NFT from the time it was deposited, then subtracts the reward already claimed
    /// @param tokenId The id of the NFT for which a reward will be calculated
    /// @return Reward available for withdrawal
    function getRewardAmount(uint256 tokenId) external view returns (uint256) {
        return _getRewardAmount(tokenId);
    }

    function _getRewardRate() private view returns (uint256) {
        return REWARD_AMOUNT_WITHOUT_DECIMALS * 10 ** i_rewardToken.decimals();
    }

    function _getRewardAmount(uint256 tokenId) private view returns (uint256) {
        uint256 timePassed;
        uint256 eligibleReward;
        unchecked {
            timePassed =
                block.timestamp -
                s_nftOwners[tokenId].depositTimestamp;
        }
        uint256 totalRewardAccumulated = (timePassed / TIME_TO_REWARD) *
            _getRewardRate();
        unchecked {
            eligibleReward = totalRewardAccumulated - s_nftRewardTally[tokenId];
        }

        return eligibleReward;
    }
}

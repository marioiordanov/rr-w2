// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "@openzeppelin/contracts@v5.0.2/token/ERC721/ERC721.sol";
import {Ownable2Step} from "@openzeppelin/contracts@v5.0.2/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts@v5.0.2/access/Ownable.sol";
import {ERC2981} from "@openzeppelin/contracts@v5.0.2/token/common/ERC2981.sol";
import {BitMaps} from "@openzeppelin/contracts@v5.0.2/utils/structs/BitMaps.sol";
import {IERC721} from "@openzeppelin/contracts@v5.0.2/interfaces/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts@v5.0.2/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC2981} from "@openzeppelin/contracts@v5.0.2/interfaces/IERC2981.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts@v5.0.2/utils/ReentrancyGuard.sol";
import {MerkleProof} from "@openzeppelin/contracts@v5.0.2/utils/cryptography/MerkleProof.sol";

/// @title NFT token with royalties
/// @author marioiordanov
/// @notice You can use this contract to buy NFTs and on each subsequent sale the owner of the contract will receive 2.5% of the price
/// @dev Contract implements ERC721, ERC2981 interfaces
/// @dev Contract have discount for some users, part of a merkle tree
contract NFT is ERC721, ERC2981, Ownable2Step, ReentrancyGuard {
    // constants
    // normal price 0.1 ether
    uint256 public constant NFT_PRICE = 0.1 ether;
    // max supply of nfts
    uint256 public constant MAX_SUPPLY = 1000;
    // discount 50%
    uint256 public constant DISCOUNT_NUMERATOR = 50;
    uint256 public constant DISCOUNT_DENOMINATOR = 100;
    // 2.5% of the price goes to the creator on each subsequent sale
    uint96 private constant REWARD_RATE_NUMERATOR = 25;
    uint96 private constant REWARED_RATE_DENOMINATOR = 1000;

    // state vars
    bytes32 private immutable i_discountsMerkleRoot;
    BitMaps.BitMap private s_nonClaimedDiscountBitMap;
    uint256 private s_currentSupply;

    // events
    event Withdraw(uint256 amount);

    // errors
    error TransferFailed();
    error MaxSupplyReached();
    error UserNotEligibleForDiscount(address user);
    error DiscountAlreadyClaimed();
    error CollectionMinted();
    error EtherValueNotEnough();

    // functions

    constructor(
        bytes32 merkleRoot
    ) ERC721("Non Fungible Token", "NFT") Ownable(msg.sender) {
        i_discountsMerkleRoot = merkleRoot;
        unchecked {
            // initialize the bitmap with all bits set to 1
            uint256 indices = (MAX_SUPPLY / 256) + 1;
            if (MAX_SUPPLY % 256 == 0) {
                indices--;
            }
            for (uint256 i = 0; i < indices; i++) {
                s_nonClaimedDiscountBitMap._data[
                        i
                    ] = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
            }
        }
        _setDefaultRoyalty(owner(), REWARD_RATE_NUMERATOR);
    }

    /// @notice Call this function to buy an NFT
    /// @dev Buys an NFT for the sender at normal price. Function is nonReentrant
    /// @return Minted NFT id
    function buyNft() external payable nonReentrant returns (uint256) {
        return _buyNft(msg.sender, msg.value, NFT_PRICE);
    }

    /// @notice Call this function to buy an NFT with discount
    /// @dev User have to provide merkle proof that his address is part of the discount list. Discount list is pair (address, idx)
    /// @param proof Merkle proof that the user is part of the discount list
    /// @param index Index of the user in the discount list
    /// @return Minted NFT id
    function buyNft(
        bytes32[] calldata proof,
        uint256 index
    ) external payable nonReentrant returns (uint256) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, index));

        if (!MerkleProof.verify(proof, i_discountsMerkleRoot, leaf)) {
            revert UserNotEligibleForDiscount(msg.sender);
        }

        if (!BitMaps.get(s_nonClaimedDiscountBitMap, index)) {
            revert DiscountAlreadyClaimed();
        }

        BitMaps.unset(s_nonClaimedDiscountBitMap, index);
        uint256 discountedPrice;
        unchecked {
            discountedPrice =
                (NFT_PRICE * DISCOUNT_NUMERATOR) /
                DISCOUNT_DENOMINATOR;
        }

        return _buyNft(msg.sender, msg.value, discountedPrice);
    }

    /// @notice Owner can withdraw the balance of the contract
    function withdraw() external onlyOwner {
        uint256 currentBalance = address(this).balance;
        emit Withdraw(currentBalance);

        (bool success, ) = payable(owner()).call{value: currentBalance}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721, ERC2981) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _feeDenominator() internal pure override returns (uint96) {
        return REWARED_RATE_DENOMINATOR;
    }

    function _buyNft(
        address buyer,
        uint256 etherSent,
        uint256 nftPrice
    ) private returns (uint256 tokenId) {
        if (s_currentSupply == MAX_SUPPLY) {
            revert MaxSupplyReached();
        }

        if (etherSent < nftPrice) {
            revert EtherValueNotEnough();
        }

        unchecked {
            tokenId = s_currentSupply++;
        }

        _safeMint(buyer, tokenId);
        // return change
        if (etherSent > nftPrice) {
            (bool success, ) = payable(buyer).call{value: etherSent - nftPrice}(
                ""
            );
            if (!success) {
                revert TransferFailed();
            }
        }
    }
}

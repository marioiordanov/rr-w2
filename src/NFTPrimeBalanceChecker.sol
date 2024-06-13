// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721Enumerable} from "@openzeppelin/contracts@v5.0.2/token/ERC721/extensions/ERC721Enumerable.sol";
import {console} from "forge-std/Console.sol";

/// @title Contract that checks how many NFTs are prime ids
/// @author marioiordanov
/// @notice If you want to check an address how many NFTs with prime token ids, you can use this contract
contract NFTPrimeBalanceChecker {
    ERC721Enumerable private immutable i_nft;
    uint256 private immutable i_nftMaxSupply;

    constructor(ERC721Enumerable nft, uint256 nftMaxSupply) {
        i_nft = nft;
        i_nftMaxSupply = nftMaxSupply;
    }

    function getPrimeNftIds(address account) external view returns (uint256) {
        unchecked {
            uint256 accountTokensLength = i_nft.balanceOf(account);
            uint256 primeTokenIds;
            uint256 j;
            uint256 i;
            uint256 tokenId;
            uint256 isNotPrime;

            for (i = 0; i < accountTokensLength; i++) {
                tokenId = i_nft.tokenOfOwnerByIndex(account, i);
                if (tokenId < 4) {
                    primeTokenIds++;
                } else {
                    isNotPrime = 0;
                    for (j = 2; j < tokenId; j++) {
                        if (tokenId % j == 0) {
                            isNotPrime = 1;
                            break;
                        }
                    }
                    if (isNotPrime == 0) {
                        primeTokenIds++;
                    }
                }
            }

            return primeTokenIds;
        }
    }
}

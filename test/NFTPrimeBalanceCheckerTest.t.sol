// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;
import {Test, console} from "forge-std/Test.sol";
import {NFTPrimeBalanceChecker} from "../src/NFTPrimeBalanceChecker.sol";
import {NFTEnumerable} from "../src/NFTEnumerable.sol";

contract NFTPrimeBalanceCheckerTest is Test {
    address private u1 = makeAddr("u1");
    address private u2 = makeAddr("u2");
    address private u3 = makeAddr("u3");
    NFTEnumerable nft;
    NFTPrimeBalanceChecker checker;

    function setUp() public {
        nft = new NFTEnumerable();
        checker = new NFTPrimeBalanceChecker(nft, nft.MAX_SUPPLY());
    }

    function testCorrectPrimeNumbersCount() public {
        mintNfts(u1, 1, 20);
        mintNfts(u2, 21, 50);
        mintNfts(u3, 51, 100);

        assertEq(checker.getPrimeNftIds(u1), 9);
        // 1,2,3,5,7,11,13,17,19
    }

    function mintNfts(address receiver, uint256 fromId, uint256 toId) private {
        for (uint256 i = fromId; i <= toId; i++) {
            nft.mint(receiver);
        }
    }
}

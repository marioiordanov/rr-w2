// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;
import {Test, console} from "forge-std/Test.sol";
import {NFT} from "../src/NFT.sol";
import {MerkleProof} from "@openzeppelin/contracts@v5.0.2/utils/cryptography/MerkleProof.sol";

import {IERC721Receiver} from "@openzeppelin/contracts@v5.0.2/token/ERC721/IERC721Receiver.sol";

contract NftTest is Test {
    NFT nft;
    address owner = makeAddr("nft owner");
    address buyer = makeAddr("nft buyer");
    address[4] usersWithDiscount = [
        address(1),
        address(2),
        address(3),
        address(4)
    ];

    bytes32[] merkleTree;

    function setUp() public {
        vm.deal(owner, 1000 ether);
        vm.deal(buyer, 1 ether);
        vm.startPrank(owner);
        merkleTree = generateDiscountMerkleTree();
        nft = new NFT(merkleTree[merkleTree.length - 1]);
        vm.stopPrank();
    }

    function testCantMintMoreThan1000Nfts() public {
        vm.startPrank(owner);
        uint256 price = nft.NFT_PRICE();
        for (uint256 i = 0; i < nft.MAX_SUPPLY(); i++) {
            nft.buyNft{value: price}();
        }
        assertEq(nft.balanceOf(owner), nft.MAX_SUPPLY());
        vm.expectRevert(NFT.MaxSupplyReached.selector);
        nft.buyNft{value: price}();
    }

    function testNftPrice() public {
        vm.startPrank(buyer);
        uint256 balanceBeforeShopping = buyer.balance;
        // user buys 5 nfts
        for (uint256 i = 0; i < 5; i++) {
            nft.buyNft{value: 2 * nft.NFT_PRICE()}();
        }

        assertGe(balanceBeforeShopping - 5 * nft.NFT_PRICE(), buyer.balance);
        assert(buyer.balance > balanceBeforeShopping - 6 * nft.NFT_PRICE());
    }

    function testNftReturnsChange() public {
        vm.startPrank(buyer);
        uint256 balanceBeforeShopping = buyer.balance;
        nft.buyNft{value: balanceBeforeShopping}();
        assert(balanceBeforeShopping - nft.NFT_PRICE() == buyer.balance);
    }

    function testNFTBuyerWithDiscount() public {
        address buyerWithDiscount = usersWithDiscount[0];
        vm.deal(buyerWithDiscount, 1 ether);
        uint256 initialBalance = buyerWithDiscount.balance;
        vm.startPrank(buyerWithDiscount);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = merkleTree[1];
        proof[1] = merkleTree[5];
        nft.buyNft{value: nft.NFT_PRICE()}(proof, 0);
        assert(buyerWithDiscount.balance > initialBalance - nft.NFT_PRICE());
        assertEq(
            buyerWithDiscount.balance,
            initialBalance -
                ((nft.NFT_PRICE() * nft.DISCOUNT_NUMERATOR()) /
                    nft.DISCOUNT_DENOMINATOR())
        );
    }

    function testNFTBuyerCantBuyMoreThanOnceWithDiscount() public {
        address buyerWithDiscount = usersWithDiscount[0];
        vm.deal(buyerWithDiscount, 1 ether);
        vm.startPrank(buyerWithDiscount);
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = merkleTree[1];
        proof[1] = merkleTree[5];
        uint256 nftPrice = nft.NFT_PRICE();
        nft.buyNft{value: nftPrice}(proof, 0);
        vm.expectRevert(NFT.DiscountAlreadyClaimed.selector);
        nft.buyNft{value: nftPrice}(proof, 0);
    }

    function testNFTCollectionOwnerCanWithdrawContractBalance() public {
        vm.startPrank(buyer);
        uint256 ownerBalanceBeforeSelling = owner.balance;
        uint256 totalValueSpendOnNfts = 0;
        for (uint256 i = 0; i < 5; i++) {
            totalValueSpendOnNfts += nft.NFT_PRICE();
            nft.buyNft{value: nft.NFT_PRICE()}();
        }

        assertEq(address(nft).balance, totalValueSpendOnNfts);
        vm.stopPrank();
        vm.startPrank(owner);
        nft.withdraw();
        assertEq(
            owner.balance,
            ownerBalanceBeforeSelling + totalValueSpendOnNfts
        );
        assertEq(address(nft).balance, 0);
    }

    function testNFTCollectionContractBalanceCantBeWithdrawnFromDifferentToOwner()
        public
    {
        vm.startPrank(buyer);
        uint256 totalValueSpendOnNfts = 0;
        for (uint256 i = 0; i < 5; i++) {
            totalValueSpendOnNfts += nft.NFT_PRICE();
            nft.buyNft{value: nft.NFT_PRICE()}();
        }

        vm.expectRevert();
        nft.withdraw();
    }

    function generateDiscountMerkleTree()
        private
        view
        returns (bytes32[] memory)
    {
        //8->4->2->1
        // 4->2->1
        // 16->8->4->2->1

        // (1,2,3,4) (h(1,2), h(3,4))

        require(
            usersWithDiscount.length % 2 == 0,
            "Number of users for discount have to be even number"
        );

        // generate leafs

        uint256 intermediateMerkleTreeArrayLength = usersWithDiscount.length;
        uint256 merkleTreeArrayLength = 1;

        while (intermediateMerkleTreeArrayLength > 1) {
            merkleTreeArrayLength += intermediateMerkleTreeArrayLength;
            intermediateMerkleTreeArrayLength =
                intermediateMerkleTreeArrayLength >>
                1;
        }

        bytes32[] memory merkleTreeArr = new bytes32[](merkleTreeArrayLength);

        // initial leafs length
        for (uint256 i = 0; i < usersWithDiscount.length; i++) {
            merkleTreeArr[i] = keccak256(
                abi.encodePacked(usersWithDiscount[i], i)
            );
        }

        // intermediate leafs
        uint256 lastRowLength = usersWithDiscount.length;
        uint256 processedElements = usersWithDiscount.length;

        while (lastRowLength > 0) {
            uint256 elementsToIterate = lastRowLength >> 1;
            // 0   1    2    3     4     5    6
            // 1   2    3    4    12    34   1234
            for (uint256 i = 0; i < elementsToIterate; i++) {
                uint256 parentIdx = processedElements + i;
                uint256 leftIdx = processedElements + (i * 2) - lastRowLength;
                uint256 rightIdx = processedElements +
                    (i * 2) +
                    1 -
                    lastRowLength;

                if (merkleTreeArr[leftIdx] < merkleTreeArr[rightIdx]) {
                    merkleTreeArr[parentIdx] = keccak256(
                        abi.encodePacked(
                            merkleTreeArr[leftIdx],
                            merkleTreeArr[rightIdx]
                        )
                    );
                } else {
                    merkleTreeArr[parentIdx] = keccak256(
                        abi.encodePacked(
                            merkleTreeArr[rightIdx],
                            merkleTreeArr[leftIdx]
                        )
                    );
                }
            }
            processedElements += elementsToIterate;
            lastRowLength = lastRowLength >> 1;
        }

        bytes32[] memory proof = new bytes32[](2);
        proof[0] = merkleTreeArr[1];
        proof[1] = merkleTreeArr[5];
        console.log(
            MerkleProof.verify(proof, merkleTreeArr[6], merkleTreeArr[0])
        );
        return merkleTreeArr;
    }
}

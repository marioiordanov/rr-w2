// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;
import {Test, console} from "forge-std/Test.sol";
import {NFTStaking} from "../src/NFTStaking.sol";
import {NFT} from "../src/NFT.sol";
import {ERC20} from "@openzeppelin/contracts@v5.0.2/token/ERC20/ERC20.sol";

contract NFTStakingTest is Test {
    NFTStaking private staking;
    NFT private nft;
    ERC20 private rewardToken;
    address private buyer = makeAddr("nft buyer");

    function setUp() public {
        nft = new NFT(0);
        staking = new NFTStaking(nft);
        rewardToken = ERC20(address(staking.i_rewardToken()));
        vm.deal(buyer, 1 ether);
    }

    function testStakingContractReceivesNft() public {
        uint256 tokenId = buyerDepositsNft();
        (, address nftOwner) = staking.s_nftOwners(tokenId);
        assertEq(nftOwner, buyer);
    }

    function testOnlyNftOwnerCanWithdrawFromStakingContract() public {
        uint256 tokenId = buyerDepositsNft();
        vm.prank(address(1));
        vm.expectRevert(NFTStaking.NotTheOwner.selector);
        staking.withdrawNFt(tokenId);

        assertEq(nft.balanceOf(buyer), 0);
        vm.prank(buyer);
        staking.withdrawNFt(tokenId);
        assertEq(nft.balanceOf(buyer), 1);
    }

    // test for the reward calculation via claimReward
    function testRewardAmountAfterTimeIsCorrect() public {
        uint256 tokenId = buyerDepositsNft();
        // 24 hours passed
        vm.warp(block.timestamp + staking.TIME_TO_REWARD());
        assertEq(
            staking.getRewardAmount(tokenId),
            staking.REWARD_AMOUNT_WITHOUT_DECIMALS() *
                10 ** rewardToken.decimals()
        );

        // 36 hours passed
        vm.warp(block.timestamp + staking.TIME_TO_REWARD() / 2);
        assertEq(
            staking.getRewardAmount(tokenId),
            staking.REWARD_AMOUNT_WITHOUT_DECIMALS() *
                10 ** rewardToken.decimals()
        );

        // 48 hours passed
        vm.warp(block.timestamp + staking.TIME_TO_REWARD() / 2);
        assertEq(
            staking.getRewardAmount(tokenId),
            2 *
                staking.REWARD_AMOUNT_WITHOUT_DECIMALS() *
                10 ** rewardToken.decimals()
        );
    }

    function testOnlyNftOwnerCanWithdrawReward() public {
        uint256 tokenId = buyerDepositsNft();
        uint256 rewardTokenBuyerInitialBalance = rewardToken.balanceOf(buyer);
        vm.warp(
            block.timestamp +
                staking.TIME_TO_REWARD() +
                (staking.TIME_TO_REWARD() / 2)
        );
        vm.prank(address(1));
        vm.expectRevert(NFTStaking.NotTheOwner.selector);
        staking.claimReward(tokenId);

        vm.prank(buyer);
        uint256 claimedReward = staking.claimReward(tokenId);
        assertEq(
            rewardToken.balanceOf(buyer),
            rewardTokenBuyerInitialBalance + claimedReward
        );
    }

    function testCantClaimRewardTwoTimes() public {
        uint256 tokenId = buyerDepositsNft();
        vm.startPrank(buyer);
        uint256 rewardTokenBuyerInitialBalance = rewardToken.balanceOf(buyer);
        vm.warp(block.timestamp + staking.TIME_TO_REWARD());
        uint256 claimedReward = staking.claimReward(tokenId);
        assertEq(
            rewardToken.balanceOf(buyer),
            rewardTokenBuyerInitialBalance + claimedReward
        );
        uint256 rewardTokenBuyerBalanceAfterFirstClaim = rewardToken.balanceOf(
            buyer
        );
        uint256 newClaimedReward = staking.claimReward(tokenId);
        assertEq(newClaimedReward, 0);

        assertEq(
            rewardTokenBuyerBalanceAfterFirstClaim,
            rewardToken.balanceOf(buyer)
        );
    }

    function testRewardIsAutomaticallyClaimedWhenWithdrawingNft() public {
        uint256 tokenId = buyerDepositsNft();
        vm.startPrank(buyer);
        uint256 rewardTokenBuyerInitialBalance = rewardToken.balanceOf(buyer);
        vm.warp(block.timestamp + staking.TIME_TO_REWARD());
        uint256 claimedReward = staking.claimReward(tokenId);
        uint256 rewardTokenBuyerBalanceAfterClaim = rewardToken.balanceOf(
            buyer
        );
        assertEq(
            rewardTokenBuyerBalanceAfterClaim,
            rewardTokenBuyerInitialBalance + claimedReward
        );
        vm.warp(block.timestamp + staking.TIME_TO_REWARD());
        staking.withdrawNFt(tokenId);
        assertEq(
            rewardToken.balanceOf(buyer),
            rewardTokenBuyerBalanceAfterClaim +
                staking.REWARD_AMOUNT_WITHOUT_DECIMALS() *
                10 ** rewardToken.decimals()
        );
        assertEq(nft.ownerOf(tokenId), buyer);
    }

    function buyerDepositsNft() private returns (uint256) {
        vm.startPrank(buyer);
        uint256 tokenId = nft.buyNft{value: nft.NFT_PRICE()}();
        nft.safeTransferFrom(buyer, address(staking), tokenId);
        vm.stopPrank();
        return tokenId;
    }
}

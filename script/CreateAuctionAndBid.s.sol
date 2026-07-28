// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console2 } from "forge-std/Script.sol";

import { AuctionFactory } from "../src/factory/AuctionFactory.sol";
import { NFTMarket } from "../src/nft/NFTMarket.sol";

/// @notice Mints an NFT, creates an ETH auction, and places one bid.
contract CreateAuctionAndBid is Script {
    function run() external returns (uint256 auctionId, uint256 tokenId) {
        uint256 sellerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 bidderPrivateKey = vm.envUint("BIDDER_PRIVATE_KEY");
        address seller = vm.addr(sellerPrivateKey);
        address bidder = vm.addr(bidderPrivateKey);

        AuctionFactory factory = AuctionFactory(payable(vm.envAddress("AUCTION_FACTORY_PROXY")));
        NFTMarket nft = NFTMarket(vm.envAddress("NFT_MARKET"));

        string memory tokenURI = vm.envOr("TOKEN_URI", string("ipfs://test-auction-nft"));
        uint256 durationHours = vm.envOr("AUCTION_DURATION_HOURS", uint256(24));
        uint256 reservePriceUSD = vm.envOr("RESERVE_PRICE_USD", uint256(1_000_000));
        uint256 bidAmount = vm.envOr("BID_ETH_WEI", uint256(0.001 ether));

        require(seller != bidder, "seller cannot bid");
        require(nft.owner() == seller, "PRIVATE_KEY is not NFT owner");
        require(durationHours > 0, "duration is zero");
        require(reservePriceUSD > 0, "reserve price is zero");
        require(bidAmount > 0, "bid amount is zero");

        vm.startBroadcast(sellerPrivateKey);
        tokenId = nft.mint(seller, tokenURI);
        nft.approve(address(factory), tokenId);
        auctionId = factory.createAuction(address(nft), tokenId, durationHours, reservePriceUSD, address(0));
        vm.stopBroadcast();

        vm.startBroadcast(bidderPrivateKey);
        factory.bidETH{ value: bidAmount }(auctionId);
        vm.stopBroadcast();

        console2.log("seller", seller);
        console2.log("bidder", bidder);
        console2.log("nftContract", address(nft));
        console2.log("tokenId", tokenId);
        console2.log("auctionId", auctionId);
        console2.log("reservePriceUSD", reservePriceUSD);
        console2.log("bidETH", bidAmount);
    }
}

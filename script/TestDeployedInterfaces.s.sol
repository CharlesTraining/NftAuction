// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console2 } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AuctionFactory } from "../src/factory/AuctionFactory.sol";
import { NFTMarket } from "../src/nft/NFTMarket.sol";

contract CheckDeployment is Script {
    function run() external view {
        AuctionFactory factory = AuctionFactory(payable(vm.envAddress("AUCTION_FACTORY_PROXY")));
        NFTMarket nft = NFTMarket(vm.envAddress("NFT_MARKET"));

        console2.log("auctionFactory proxy", address(factory));
        console2.log("auctionFactory owner", factory.owner());
        console2.log("platformFee", factory.platformFee());
        console2.log("feeRecipient", factory.feeRecipient());
        console2.log("ethUsdFeed", address(factory.ethUsdFeed()));
        console2.log("nextAuctionId", factory.nextAuctionId());
        console2.log("nftMarket", address(nft));
        console2.log("nft owner", nft.owner());
        console2.log("nft totalSupply", nft.totalSupply());

        (bool ok, bytes memory data) = address(factory).staticcall(abi.encodeWithSignature("version()"));
        if (ok && data.length >= 32) {
            console2.log("factory version", abi.decode(data, (uint256)));
        } else {
            console2.log("factory version", "V1 or version() unavailable");
        }
    }
}

contract ReadAuction is Script {
    function run() external view {
        AuctionFactory factory = AuctionFactory(payable(vm.envAddress("AUCTION_FACTORY_PROXY")));
        uint256 auctionId = vm.envUint("AUCTION_ID");

        (
            address nftContract,
            uint256 tokenId,
            address seller,
            uint256 endTime,
            uint256 reservePriceUSD,
            address bidToken,
            address highestBidder,
            uint256 highestBid,
            uint256 ended
        ) = factory.auctions(auctionId);

        console2.log("auctionId", auctionId);
        console2.log("nftContract", nftContract);
        console2.log("tokenId", tokenId);
        console2.log("seller", seller);
        console2.log("endTime", endTime);
        console2.log("reservePriceUSD", reservePriceUSD);
        console2.log("bidToken", bidToken);
        console2.log("highestBidder", highestBidder);
        console2.log("highestBid", highestBid);
        console2.log("ended", ended);
    }
}

contract MintAndCreateEthAuction is Script {
    function run() external returns (uint256 auctionId, uint256 tokenId) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address seller = vm.addr(privateKey);
        AuctionFactory factory = AuctionFactory(payable(vm.envAddress("AUCTION_FACTORY_PROXY")));
        NFTMarket nft = NFTMarket(vm.envAddress("NFT_MARKET"));

        string memory tokenURI = vm.envOr("TOKEN_URI", string("ipfs://demo-token"));
        uint256 durationHours = vm.envOr("AUCTION_DURATION_HOURS", uint256(1));
        uint256 reservePriceUSD = vm.envOr("RESERVE_PRICE_USD", uint256(1_000_000_000));

        vm.startBroadcast(privateKey);

        tokenId = nft.mint(seller, tokenURI);
        nft.approve(address(factory), tokenId);
        auctionId = factory.createAuction(address(nft), tokenId, durationHours, reservePriceUSD, address(0));

        vm.stopBroadcast();

        console2.log("seller", seller);
        console2.log("tokenId", tokenId);
        console2.log("auctionId", auctionId);
        console2.log("reservePriceUSD", reservePriceUSD);
    }
}

contract BidEthAuction is Script {
    function run() external {
        uint256 privateKey = vm.envUint("BIDDER_PRIVATE_KEY");
        address bidder = vm.addr(privateKey);
        AuctionFactory factory = AuctionFactory(payable(vm.envAddress("AUCTION_FACTORY_PROXY")));
        uint256 auctionId = vm.envUint("AUCTION_ID");
        uint256 bidAmount = vm.envOr("BID_ETH_WEI", uint256(1 ether));

        vm.startBroadcast(privateKey);
        factory.bidETH{ value: bidAmount }(auctionId);
        vm.stopBroadcast();

        console2.log("bidder", bidder);
        console2.log("auctionId", auctionId);
        console2.log("bidETH", bidAmount);
    }
}

contract SetERC20Feed is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        AuctionFactory factory = AuctionFactory(payable(vm.envAddress("AUCTION_FACTORY_PROXY")));
        address bidToken = vm.envAddress("BID_TOKEN");
        address tokenUsdFeed = vm.envAddress("TOKEN_USD_FEED");

        vm.startBroadcast(privateKey);
        factory.setERC20Feed(bidToken, tokenUsdFeed);
        vm.stopBroadcast();

        console2.log("bidToken", bidToken);
        console2.log("tokenUsdFeed", tokenUsdFeed);
    }
}

contract MintAndCreateERC20Auction is Script {
    function run() external returns (uint256 auctionId, uint256 tokenId) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address seller = vm.addr(privateKey);
        AuctionFactory factory = AuctionFactory(payable(vm.envAddress("AUCTION_FACTORY_PROXY")));
        NFTMarket nft = NFTMarket(vm.envAddress("NFT_MARKET"));
        address bidToken = vm.envAddress("BID_TOKEN");

        string memory tokenURI = vm.envOr("TOKEN_URI", string("ipfs://demo-token"));
        uint256 durationHours = vm.envOr("AUCTION_DURATION_HOURS", uint256(1));
        uint256 reservePriceUSD = vm.envOr("RESERVE_PRICE_USD", uint256(1_000_000_000));

        vm.startBroadcast(privateKey);

        tokenId = nft.mint(seller, tokenURI);
        nft.approve(address(factory), tokenId);
        auctionId = factory.createAuction(address(nft), tokenId, durationHours, reservePriceUSD, bidToken);

        vm.stopBroadcast();

        console2.log("seller", seller);
        console2.log("tokenId", tokenId);
        console2.log("auctionId", auctionId);
        console2.log("bidToken", bidToken);
        console2.log("reservePriceUSD", reservePriceUSD);
    }
}

contract BidERC20Auction is Script {
    function run() external {
        uint256 privateKey = vm.envUint("BIDDER_PRIVATE_KEY");
        address bidder = vm.addr(privateKey);
        AuctionFactory factory = AuctionFactory(payable(vm.envAddress("AUCTION_FACTORY_PROXY")));
        IERC20 bidToken = IERC20(vm.envAddress("BID_TOKEN"));
        uint256 auctionId = vm.envUint("AUCTION_ID");
        uint256 bidAmount = vm.envUint("BID_TOKEN_AMOUNT");

        vm.startBroadcast(privateKey);
        bidToken.approve(address(factory), bidAmount);
        factory.bidERC20(auctionId, bidAmount);
        vm.stopBroadcast();

        console2.log("bidder", bidder);
        console2.log("auctionId", auctionId);
        console2.log("bidToken", address(bidToken));
        console2.log("bidAmount", bidAmount);
    }
}

contract EndAuction is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        AuctionFactory factory = AuctionFactory(payable(vm.envAddress("AUCTION_FACTORY_PROXY")));
        uint256 auctionId = vm.envUint("AUCTION_ID");

        vm.startBroadcast(privateKey);
        factory.endAuction(auctionId);
        vm.stopBroadcast();

        console2.log("auctionId", auctionId);
        console2.log("ended", true);
    }
}

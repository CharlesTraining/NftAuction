// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Script, console2 } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { AuctionFactory } from "../src/factory/AuctionFactory.sol";
import { NFTMarket } from "../src/nft/NFTMarket.sol";

contract Deploy is Script {
    function run() external returns (AuctionFactory factory, NFTMarket nft) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address feeRecipient = vm.envOr("FEE_RECIPIENT", deployer);
        address ethUsdFeed = vm.envAddress("ETH_USD_FEED");

        string memory nftName = vm.envOr("NFT_NAME", string("Demo NFT"));
        string memory nftSymbol = vm.envOr("NFT_SYMBOL", string("DNFT"));

        vm.startBroadcast(deployerPrivateKey);

        AuctionFactory implementation = new AuctionFactory();
        bytes memory initData = abi.encodeCall(AuctionFactory.initialize, (feeRecipient, ethUsdFeed));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        factory = AuctionFactory(payable(address(proxy)));

        nft = new NFTMarket(nftName, nftSymbol);

        vm.stopBroadcast();

        console2.log("deployer", deployer);
        console2.log("auctionFactory implementation", address(implementation));
        console2.log("auctionFactory proxy", address(factory));
        console2.log("nftMarket", address(nft));
        console2.log("feeRecipient", feeRecipient);
        console2.log("ethUsdFeed", ethUsdFeed);
    }
}
